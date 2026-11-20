#!/usr/bin/env python3

"""Evaluate mini-SWE-agent predictions for SWE-bench."""

import concurrent.futures
import importlib.util
import json
import subprocess
import sys
import threading
import time
import traceback
import uuid
from pathlib import Path
from typing import Any

import typer
from rich.live import Live

from minisweagent.config import builtin_config_dir, get_config_from_spec
from minisweagent.run.benchmarks.swebench import filter_instances, get_sb_environment
from minisweagent.run.benchmarks.utils.batch_progress import RunBatchProgressManager
from minisweagent.utils.log import add_file_handler, logger
from minisweagent.utils.serialize import UNSET, recursive_merge

_HELP_TEXT = """Evaluate SWE-bench predictions.

By default, instances must contain an `eval_script` column. Use
`--backend official` to invoke the official SWE-bench evaluation harness instead.
"""

DEFAULT_CONFIG_FILE = builtin_config_dir / "benchmarks" / "swebench.yaml"

app = typer.Typer(rich_markup_mode="rich", add_completion=False)
_OUTPUT_FILE_LOCK = threading.Lock()


def update_evals_file(
    output_path: Path,
    instance_id: str,
    model_name: str,
    model_patch: str,
    eval_report: dict[str, Any],
) -> None:
    """Update the evaluation JSON file with the result for a single instance."""
    with _OUTPUT_FILE_LOCK:
        output_data = {}
        if output_path.exists():
            output_data = json.loads(output_path.read_text())
        output_data[instance_id] = {
            "model_name_or_path": model_name,
            "instance_id": instance_id,
            "model_patch": model_patch,
            "eval_report": eval_report,
        }
        output_path.write_text(json.dumps(output_data, indent=2))


def remove_from_evals_file(output_path: Path, instance_id: str) -> None:
    """Remove an instance from the evaluations file."""
    if not output_path.exists():
        return
    with _OUTPUT_FILE_LOCK:
        output_data = json.loads(output_path.read_text())
        if instance_id in output_data:
            del output_data[instance_id]
            output_path.write_text(json.dumps(output_data, indent=2))


def evaluate_instance(
    instance: dict,
    output_dir: Path,
    instance_result: dict[str, Any],
    config: dict,
    progress_manager: RunBatchProgressManager | None = None,
) -> None:
    """Evaluate a single prediction by applying its patch and running ``eval_script``."""
    instance_id = instance["instance_id"]
    output_path = output_dir / "evals.json"
    model_patch = instance_result.get("model_patch") or ""
    model_name = (
        instance_result.get("model_name_or_path")
        or config.get("model", {}).get("model_name")
        or "unknown"
    )

    if progress_manager is not None:
        progress_manager.update_instance_status(instance_id, "Evaluating")

    remove_from_evals_file(output_path, instance_id)
    eval_report: dict[str, Any] = {"instance_id": instance_id, "resolved": False, "eval_error": None}

    env = None
    try:
        if not model_patch.strip():
            raise ValueError("Prediction has an empty model patch")

        eval_script = instance.get("eval_script")
        if not eval_script:
            raise ValueError("Dataset instance does not define an `eval_script` column")

        env = get_sb_environment(config, instance)

        delimiter = f"PATCH_{uuid.uuid4().hex}"
        apply_command = f"git apply <<'{delimiter}'\n{model_patch}\n{delimiter}"
        obs = env.execute({"command": apply_command})
        if obs["returncode"] != 0:
            eval_report["eval_error"] = obs.get("output", "git apply failed")
        else:
            eval_command = f"bash <<'EOF'\n{eval_script}\nEOF"
            obs = env.execute({"command": eval_command})
            eval_report["resolved"] = obs["returncode"] == 0
            if not eval_report["resolved"]:
                eval_report["eval_error"] = obs.get("output", "Evaluation script failed")
    except Exception as e:
        eval_report["eval_error"] = str(e)
        logger.error(f"Error evaluating instance {instance_id}: {e}", exc_info=True)
    finally:
        if env is not None and hasattr(env, "cleanup"):
            try:
                env.cleanup()
            except Exception:
                logger.debug(f"Could not clean up environment for {instance_id}", exc_info=True)
        update_evals_file(output_path, instance_id, model_name, model_patch, eval_report)
        if progress_manager is not None:
            progress_manager.on_instance_end(instance_id, "Resolved" if eval_report["resolved"] else "Unresolved")


def _load_predictions(predictions_path: Path) -> dict[str, dict[str, Any]]:
    """Load predictions from the dictionary written by the batch runner."""
    predictions = json.loads(predictions_path.read_text())
    if isinstance(predictions, list):
        return {prediction["instance_id"]: prediction for prediction in predictions}
    return predictions


def write_predictions_jsonl(
    predictions_path: Path,
    jsonl_path: Path,
    instance_ids: list[str] | None = None,
) -> list[str]:
    """Convert the batch runner's ``preds.json`` to SWE-bench's JSONL format."""
    predictions = _load_predictions(predictions_path)
    selected = instance_ids or list(predictions)
    with jsonl_path.open("w") as f:
        for instance_id in selected:
            prediction = predictions.get(instance_id)
            if prediction is None:
                continue
            entry = {
                "model_name_or_path": prediction.get("model_name_or_path", "unknown"),
                "instance_id": instance_id,
                "model_patch": prediction.get("model_patch", ""),
            }
            f.write(json.dumps(entry) + "\n")
    return selected


def get_swebench_evaluation_command(
    dataset_name: str,
    split: str,
    predictions_path: Path,
    max_workers: int,
    run_id: str,
    instance_ids: list[str] | None = None,
) -> list[str]:
    """Build the command for the official SWE-bench local evaluation harness."""
    command = [
        sys.executable,
        "-m",
        "swebench.harness.run_evaluation",
        "--dataset_name",
        dataset_name,
        "--split",
        split,
        "--predictions_path",
        str(predictions_path),
        "--max_workers",
        str(max_workers),
        "--run_id",
        run_id,
    ]
    if instance_ids:
        command.extend(["--instance_ids", *instance_ids])
    return command


def run_official_evaluation(
    dataset_name: str,
    split: str,
    output_dir: Path,
    max_workers: int,
    *,
    run_id: str | None = None,
    instance_ids: list[str] | None = None,
) -> subprocess.CompletedProcess:
    """Run the official SWE-bench evaluation harness for generated predictions."""
    if importlib.util.find_spec("swebench") is None:
        raise ModuleNotFoundError(
            "The official SWE-bench harness is not installed. Install it with "
            "`pip install swebench` or evaluate with `--backend internal`."
        )

    predictions_path = output_dir / "preds.jsonl"
    write_predictions_jsonl(output_dir / "preds.json", predictions_path, instance_ids)
    run_id = run_id or f"mini-swe-agent-{int(time.time())}"
    command = get_swebench_evaluation_command(
        dataset_name, split, predictions_path, max_workers, run_id, instance_ids
    )
    logger.info(f"Running official SWE-bench evaluation: {' '.join(command)}")
    return subprocess.run(command, check=True)


def _dataset_has_eval_scripts(instances: list[dict]) -> bool:
    return bool(instances) and all(bool(instance.get("eval_script")) for instance in instances)


# fmt: off
@app.command(help=_HELP_TEXT)
def main(
    dataset: str = typer.Option("SumanthRH/SWE-Bench_Verified", "--dataset", help="Dataset name or path with an `eval_script` column for internal evaluation", rich_help_panel="Data selection"),
    split: str = typer.Option("test", "--split", help="Dataset split", rich_help_panel="Data selection"),
    slice_spec: str = typer.Option("", "--slice", help="Slice specification (e.g., '0:5' for first 5 instances)", rich_help_panel="Data selection"),
    filter_spec: str = typer.Option("", "--filter", help="Filter instance IDs by regex", rich_help_panel="Data selection"),
    shuffle: bool = typer.Option(False, "--shuffle", help="Shuffle instances", rich_help_panel="Data selection"),
    output: str = typer.Option(".", "-o", "--output", help="Output directory containing preds.json", rich_help_panel="Basic"),
    workers: int = typer.Option(1, "-w", "--workers", help="Number of worker threads for parallel processing", rich_help_panel="Basic"),
    model: str | None = typer.Option(None, "-m", "--model", help="Model name (only used for environment config)", rich_help_panel="Basic"),
    model_class: str | None = typer.Option(None, "--model-class", help="Model class used for environment config", rich_help_panel="Advanced"),
    redo_existing: bool = typer.Option(False, "--redo-existing", help="Redo existing instances", rich_help_panel="Data selection"),
    config_spec: list[str] = typer.Option([str(DEFAULT_CONFIG_FILE)], "-c", "--config", help="Path to config files, filenames, or key-value pairs", rich_help_panel="Basic"),
    environment_class: str | None = typer.Option(None, "--environment-class", help="Environment type to use. Recommended are docker or singularity", rich_help_panel="Advanced"),
    backend: str = typer.Option("auto", "--backend", help="Evaluation backend: auto, internal, or official", rich_help_panel="Advanced"),
    run_id: str = typer.Option("", "--run-id", help="Run ID for the official SWE-bench harness", rich_help_panel="Advanced"),
) -> None:
    # fmt: on
    if backend not in {"auto", "internal", "official"}:
        raise typer.BadParameter("backend must be one of: auto, internal, official")

    output_path = Path(output)
    output_path.mkdir(parents=True, exist_ok=True)
    predictions_file = output_path / "preds.json"
    if not predictions_file.exists():
        raise FileNotFoundError(f"Expected a `preds.json` file in output directory {output_path}")
    logger.info(f"Evaluations will be saved to {output_path / 'evals.json'}")
    add_file_handler(output_path / "minisweagent_eval.log")

    from datasets import load_dataset

    logger.info(f"Loading dataset {dataset}, split {split}...")
    instances = list(load_dataset(dataset, split=split))
    instances = filter_instances(instances, filter_spec=filter_spec, slice_spec=slice_spec, shuffle=shuffle)

    if not redo_existing and (output_path / "evals.json").exists():
        existing_instances = list(json.loads((output_path / "evals.json").read_text()).keys())
        logger.info(f"Skipping {len(existing_instances)} existing instances")
        instances = [instance for instance in instances if instance["instance_id"] not in existing_instances]

    use_official = backend == "official" or (backend == "auto" and not _dataset_has_eval_scripts(instances))
    if use_official:
        run_official_evaluation(
            dataset_name=dataset,
            split=split,
            output_dir=output_path,
            max_workers=workers,
            run_id=run_id or None,
            instance_ids=[instance["instance_id"] for instance in instances],
        )
        return

    if not instances:
        logger.info("No instances to evaluate")
        return

    logger.info(f"Evaluating {len(instances)} instances...")
    configs = [get_config_from_spec(spec) for spec in config_spec]
    configs.append({
        "environment": {"environment_class": environment_class or UNSET},
        "model": {"model_name": model or UNSET, "model_class": model_class or UNSET},
    })
    config = recursive_merge(*configs)
    predictions = _load_predictions(predictions_file)

    progress_manager = RunBatchProgressManager(
        len(instances), output_path / f"exit_statuses_eval_{time.time()}.yaml"
    )

    def process_futures(futures: dict[concurrent.futures.Future, str]) -> None:
        for future in concurrent.futures.as_completed(futures):
            try:
                future.result()
            except concurrent.futures.CancelledError:
                pass
            except Exception as e:
                instance_id = futures[future]
                logger.error(f"Error in future for instance {instance_id}: {e}", exc_info=True)
                progress_manager.on_uncaught_exception(instance_id, e)

    with Live(progress_manager.render_group, refresh_per_second=4):
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(
                    evaluate_instance,
                    instance,
                    output_path,
                    predictions.get(instance["instance_id"], {}),
                    config,
                    progress_manager,
                ): instance["instance_id"]
                for instance in instances
            }
            try:
                process_futures(futures)
            except KeyboardInterrupt:
                logger.info("Cancelling all pending jobs. Press ^C again to exit immediately.")
                for future in futures:
                    if not future.running() and not future.done():
                        future.cancel()
                process_futures(futures)


if __name__ == "__main__":
    app()
