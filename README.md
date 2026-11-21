# SE433 Final Project: Improving Regression Test Generation with mini-SWE-agent

## Project Overview

This project investigates whether providing an LLM-based software testing agent with examples of common software defect patterns improves its ability to generate effective and efficient regression tests.

The experiment uses mini-SWE-agent with the DeepSeek-Flash language model and evaluates generated regression tests using SWT-Bench.

The complete experiment consists of two configurations evaluated against the same 24 software defect instances.

## Research Question

Does providing an LLM with instructions and examples of common software development defect patterns improve its ability to generate regression tests effectively and efficiently?

## Experimental Design

Two configurations were evaluated:

- **Baseline:** mini-SWE-agent using the baseline prompt configuration.
- **Experimental:** The same agent and language model, with an additional prompt section containing ten common software defect patterns, accompanying code examples, and instructions on considering these patterns during test generation.

The experimental treatment modified the prompt context rather than the underlying agent execution workflow.

Both configurations used:

- DeepSeek-Flash through LiteLLM
- The same 24 SWT-Bench instances
- The SWE-bench Lite test split
- One generation worker
- The same SWT-Bench evaluation procedure
- One evaluation worker

The agent was tasked with generating regression tests that reproduce reported defects, not modifying application code to fix them.

## Results Summary

| Metric | Baseline | Experimental |
|---|---:|---:|
| Instances evaluated | 24 | 24 |
| Successfully reproduced | 10 | 10 |
| Reproduction success rate | 41.67% | 41.67% |
| Mean coverage | 80.73% | 77.95% |
| Mean coverage delta | 0.6349 | 0.6210 |
| Recorded LLM inference cost | $0.28046 | $0.26036 |
| LLM API calls | 508 | 509 |
| Generation-run execution time | 35m 30s | 32m 12s |

The experimental configuration achieved the same overall issue reproduction success rate as the baseline, while reducing recorded LLM cost by approximately 7.17% and generation-run execution time by approximately 9.31%.

The successful instances differed between configurations:

- Eight instances were successfully reproduced by both configurations.
- Twelve instances remained unresolved in both configurations.
- Two instances were resolved only by the experimental configuration: `pytest-dev__pytest-11143` and `sympy__sympy-11897`.
- Two instances were resolved only by the baseline configuration: `pytest-dev__pytest-5103` and `pytest-dev__pytest-6116`.

These findings do not establish a consistent improvement in test-generation effectiveness, although the experimental run showed lower computational cost and execution time.

## Repository Structure

The relevant project directories and files are:

```text
SE433FinalProject/
├── mini-swe-agent/
│   ├── src/minisweagent/
│   │   ├── config/benchmarks/
│   │   │   ├── swtbench_baseline.yaml
│   │   │   └── swtbench_context.yaml
│   │   └── run/benchmarks/
│   └── results/
│       ├── deepseek_flash_test_baseline/
│       │   └── preds.jsonl
│       └── deepseek_flash_test_context/
│           └── preds.jsonl
├── SWTBench/
│   └── swt-bench/
│       ├── dataset/
│       │   └── filter_cases_lite.txt
│       └── src/
└── README.md
```

The directory tree highlights the principal experiment files and is not an exhaustive listing.

## Reproducing the Experiment

The experiment consists of two stages:

1. Generate regression test patches using mini-SWE-agent and DeepSeek-Flash.
2. Evaluate the generated patches using SWT-Bench.

Commands below are written for a Linux or WSL shell. All relative paths assume the repository directory structure shown above.

### Prerequisites

The experiment requires:

- Python and the dependencies required by the included mini-SWE-agent and SWT-Bench projects
- A configured Python virtual environment for mini-SWE-agent
- Docker and the dependencies required by SWT-Bench evaluation
- Access to the DeepSeek-Flash model through LiteLLM
- Appropriate model API credentials

Install and configure each project's dependencies according to its included setup instructions.

### Step 1: Select the SWT-Bench Instances

The 24 instances used in the experiment are identified in:

`SWTBench/swt-bench/dataset/filter_cases_lite.txt`

From the repository root, enter the mini-SWE-agent directory:

```bash
cd mini-swe-agent
```

Initialize the `FILTER` variable:

```bash
FILTER=$(paste -sd '|' ../SWTBench/swt-bench/dataset/filter_cases_lite.txt)
```

This command reads the instance identifiers and joins them with `|` characters, creating the regular expression used by mini-SWE-agent's `--filter` argument.

To display the selected instances:

```bash
echo "$FILTER" | tr '|' '\n'
```

The same filter must be used for both configurations.

### Step 2: Generate Baseline Regression Tests

From the `mini-swe-agent/` directory, execute:

```bash
.venv/bin/mini-extra swebench \
    --subset lite \
    --split test \
    --filter "^($FILTER)$" \
    --workers 1 \
    --output results/deepseek_flash_test_baseline \
    --config src/minisweagent/config/benchmarks/swtbench_baseline.yaml \
    --model-class litellm \
    --model deepseek/deepseek-flash
```

The generated prediction file is expected at:

`mini-swe-agent/results/deepseek_flash_test_baseline/preds.jsonl`

### Step 3: Generate Experimental Regression Tests

Using the same working directory and instance filter, execute:

```bash
.venv/bin/mini-extra swebench \
    --subset lite \
    --split test \
    --filter "^($FILTER)$" \
    --workers 1 \
    --output results/deepseek_flash_test_context \
    --config src/minisweagent/config/benchmarks/swtbench_context.yaml \
    --model-class litellm \
    --model deepseek/deepseek-flash
```

The generated prediction file is expected at:

`mini-swe-agent/results/deepseek_flash_test_context/preds.jsonl`

The only intended differences between the generation configurations are the prompt configuration and the output directory.

### Step 4: Evaluate the Baseline Predictions

From the repository root, enter the SWT-Bench directory:

```bash
cd ../SWTBench/swt-bench
```

Execute:

```bash
python -m src.main \
    --dataset_name princeton-nlp/SWE-bench_Lite \
    --predictions_path ../../mini-swe-agent/results/deepseek_flash_test_baseline/preds.jsonl \
    --max_workers 1 \
    --run_id deepseek_flash_test_baseline
```

### Step 5: Evaluate the Experimental Predictions

From the same `SWTBench/swt-bench/` directory, execute:

```bash
python -m src.main \
    --dataset_name princeton-nlp/SWE-bench_Lite \
    --predictions_path ../../mini-swe-agent/results/deepseek_flash_test_context/preds.jsonl \
    --max_workers 1 \
    --run_id deepseek_flash_test_context
```

Both evaluation commands use the same dataset and worker count. The prediction file and run identifier differ.

The relative paths are resolved from the `SWTBench/swt-bench/` working directory.

## Evaluation Metrics

The following measurements were used to compare the two configurations.

### Issue Reproduction Success Rate

The percentage of evaluated instances classified as successfully reproduced by SWT-Bench.

A successful reproduction requires generated tests to demonstrate the reported defect against the defective version and pass after the reference fix, subject to the benchmark's validation criteria.

### Code Coverage

Mean code coverage and mean coverage delta were obtained from the SWT-Bench evaluation results.

### Computational Cost

Recorded LLM inference costs and API call counts were obtained from the generation results.

### Execution Time

Generation-run execution time was measured for each configuration. These measurements include generation execution overhead but exclude initial dataset loading and subsequent SWT-Bench evaluation.

## Generated Artifacts

The project includes the following categories of artifacts:

- Baseline and experimental prompt configurations
- Generated regression test patches
- Prediction JSONL files
- Agent generation logs
- SWT-Bench evaluation results
- Per-instance reproduction outcomes
- Computational cost records

Generation outputs are located under `mini-swe-agent/results/`.

The exact locations of the evaluation archives, per-instance comparison records, and other supporting artifacts should be documented here after their final repository locations are verified.

## Reproducibility Notes

The experiment used one full baseline run and one full experimental run, each evaluating the same 24 instances.

Because LLM-generated outputs may vary between executions, rerunning the commands may not produce identical test patches, reproduction outcomes, costs, or execution times.

The baseline and experimental configuration files preserve the prompt configurations used for comparison.

**Additional reproducibility details to document:** the exact agent stopping rules, final candidate selection procedure, dependency versions, and any relevant execution limits.

## Threats to Validity

The experiment has several limitations.

First, SWT-Bench's resolved/unresolved classification does not fully capture differences in the number, breadth, or quality of generated regression tests.

Second, the sample contains only 24 instances, limiting the generalizability of the findings.

Third, the nondeterministic nature of LLM outputs introduces possible run-to-run variation. Since each configuration was evaluated in one full run, the observed efficiency differences cannot be attributed conclusively to the prompt modification.

Finally, all ten defect-pattern examples were introduced together. The experiment therefore cannot isolate the effects of individual examples.

## Contributions

M. Kottal - Initial experiment design, experiment execution, evaluation, analysis, and report writing.
K. Gacek - Initial experiment design

## References

- [mini-SWE-agent](https://github.com/SWE-agent/mini-swe-agent)
- [SWT-Bench](https://github.com/logic-star-ai/swt-bench)
- [SWE-bench Lite dataset](https://huggingface.co/datasets/princeton-nlp/SWE-bench_Lite)
