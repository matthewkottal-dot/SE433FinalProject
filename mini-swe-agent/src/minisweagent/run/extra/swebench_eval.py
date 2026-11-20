"""Backwards-compatible import location for the SWE-bench evaluator."""

from minisweagent.run.benchmarks.swebench_eval import (  # noqa: F401
    app,
    evaluate_instance,
    get_swebench_evaluation_command,
    main,
    remove_from_evals_file,
    run_official_evaluation,
    update_evals_file,
    write_predictions_jsonl,
)

if __name__ == "__main__":
    app()
