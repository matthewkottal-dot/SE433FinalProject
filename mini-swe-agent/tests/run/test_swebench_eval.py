import json
from pathlib import Path
from unittest.mock import Mock, patch

from minisweagent.run.benchmarks.swebench_eval import (
    evaluate_instance,
    get_swebench_evaluation_command,
    remove_from_evals_file,
    update_evals_file,
    write_predictions_jsonl,
)


def test_update_and_remove_evals_file(tmp_path):
    evals_path = tmp_path / "evals.json"
    update_evals_file(evals_path, "repo__test-1", "model", "patch", {"resolved": True})
    update_evals_file(evals_path, "repo__test-2", "model", "patch", {"resolved": False})

    data = json.loads(evals_path.read_text())
    assert data["repo__test-1"]["eval_report"]["resolved"] is True
    assert data["repo__test-2"]["eval_report"]["resolved"] is False

    remove_from_evals_file(evals_path, "repo__test-1")
    assert list(json.loads(evals_path.read_text())) == ["repo__test-2"]


def test_evaluate_instance_applies_patch_and_eval_script(tmp_path):
    env = Mock()
    env.execute.side_effect = [
        {"returncode": 0, "output": ""},
        {"returncode": 0, "output": "tests passed"},
    ]
    with patch("minisweagent.run.benchmarks.swebench_eval.get_sb_environment", return_value=env):
        evaluate_instance(
            instance={"instance_id": "repo__test-1", "eval_script": "pytest -q"},
            output_dir=tmp_path,
            instance_result={"model_patch": "diff --git a/f b/f", "model_name_or_path": "test-model"},
            config={},
        )

    patch_command = env.execute.call_args_list[0].args[0]["command"]
    eval_command = env.execute.call_args_list[1].args[0]["command"]
    assert "git apply" in patch_command
    assert "diff --git a/f b/f" in patch_command
    assert "pytest -q" in eval_command
    assert json.loads((tmp_path / "evals.json").read_text())["repo__test-1"]["eval_report"] == {
        "instance_id": "repo__test-1",
        "resolved": True,
        "eval_error": None,
    }


def test_evaluate_instance_records_failed_patch(tmp_path):
    env = Mock()
    env.execute.return_value = {"returncode": 1, "output": "patch failed"}
    with patch("minisweagent.run.benchmarks.swebench_eval.get_sb_environment", return_value=env):
        evaluate_instance(
            instance={"instance_id": "repo__test-1", "eval_script": "pytest -q"},
            output_dir=tmp_path,
            instance_result={"model_patch": "bad patch", "model_name_or_path": "test-model"},
            config={},
        )

    report = json.loads((tmp_path / "evals.json").read_text())["repo__test-1"]["eval_report"]
    assert report["resolved"] is False
    assert report["eval_error"] == "patch failed"


def test_write_predictions_jsonl_filters_to_requested_instances(tmp_path):
    preds_path = tmp_path / "preds.json"
    preds_path.write_text(json.dumps({
        "repo__test-1": {
            "model_name_or_path": "model",
            "instance_id": "repo__test-1",
            "model_patch": "patch-1",
        },
        "repo__test-2": {
            "model_name_or_path": "model",
            "instance_id": "repo__test-2",
            "model_patch": "patch-2",
        },
    }))
    jsonl_path = tmp_path / "preds.jsonl"

    assert write_predictions_jsonl(preds_path, jsonl_path, ["repo__test-2"]) == ["repo__test-2"]
    assert [json.loads(line) for line in jsonl_path.read_text().splitlines()] == [
        {"model_name_or_path": "model", "instance_id": "repo__test-2", "model_patch": "patch-2"}
    ]


def test_get_swebench_evaluation_command_contains_instance_filter():
    command = get_swebench_evaluation_command(
        "princeton-nlp/SWE-bench_Verified",
        "test",
        Path("preds.jsonl"),
        4,
        "run-1",
        ["repo__test-1"],
    )
    assert command[-2:] == ["--instance_ids", "repo__test-1"]
    assert command[command.index("--dataset_name") + 1] == "princeton-nlp/SWE-bench_Verified"
    assert command[command.index("--max_workers") + 1] == "4"
