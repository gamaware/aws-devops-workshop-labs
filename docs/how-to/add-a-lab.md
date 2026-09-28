# Add a lab

This guide adds lab `NN-topic` so that `make verify` grades it like the existing five. Use the next free
two-digit number and a short, hyphenated topic, for example `06-eventbridge-rules`.

## Create the directory

```text
labs/NN-topic/
├── README.md        the tutorial
├── starter/         what the participant edits: valid, incomplete
├── solution/        the model answer
└── tests/
    └── run.sh       the grader, executable
```

## Write the README

`scripts/check_docs.py` requires these `##` sections, in this order:

1. Objectives
2. Prerequisites
3. Duration
4. Scenario
5. Steps
6. Expected result
7. Reset

Set the scenario at Harbor Goods, the fictional client of every lab. Use `111122223333` for account IDs and
`example.com` for domains. Tell the participant to run `make check LAB=NN` in **Expected result** and
`make reset LAB=NN` in **Reset**, plus any `terraform destroy` or cleanup for optional live steps.

## Write the starter and the solution

- The solution meets every objective. It is the only code that checkov, Trivy and Semgrep scan.
- The starter parses, initializes and validates, but leaves at least one objective open. The grader must return
  exit 1 on it, never 2.
- List the starter's expected failures in `tests/starter-failures.txt`: the grader's `FAIL` lines and pytest's
  `FAILED` test IDs, sorted with `LC_ALL=C sort`. The format is in the
  [grader contract](../reference/grader-contract.md).
- For Terraform, commit a `.terraform.lock.hcl` in each root and module directory of both, and pin the provider
  with the same `>= 6.0, < 7.0` constraint as the other labs.
- Starter-only lint findings belong to the exercise. The scanner configurations already skip `labs/*/starter`.

## Write the grader

`tests/run.sh` sources the shared helpers and follows the [grader contract](../reference/grader-contract.md):

```bash
#!/usr/bin/env bash
# Grader for lab NN: one line on what it checks.
# Usage: labs/NN-topic/tests/run.sh <starter-or-solution-directory>
set -euo pipefail

# shellcheck source=../../../scripts/lib/grader.sh
source "$(dirname "$0")/../../../scripts/lib/grader.sh"
TESTS="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(resolve_target "$@")"
require_tool terraform

cp -R "$TARGET/." "$GRADER_WORK/"

setup "terraform init" tf_init "$GRADER_WORK"
check "the queue is encrypted" tf_test "$GRADER_WORK" "$TESTS"

finish
```

- Use `setup` for preconditions: a failure stops the grader with exit 2.
- Use `check` for objectives: one line per objective, each phrased as the outcome the participant reaches.
- Grade the copy in `$GRADER_WORK`, never the participant's directory.
- Stay offline: mocked providers, synthesized templates, local containers. No AWS credentials.

Make it executable:

```bash
chmod +x labs/NN-topic/tests/run.sh
```

## Add the instructor notes

Create `instructor/NN-topic.md` with timing, common mistakes and discussion prompts. `scripts/check_docs.py`
fails without it.

## Register the lab

- Add a row for the lab to the lab table in the root `README.md`, with a link to `labs/NN-topic`. The docs check
  fails if the root README does not mention `labs/NN-topic`.
- Add the lab to the tutorial list in [the documentation map](../README.md).
- Scanners and updates:
  - `.checkov.yaml`: add `labs/NN-topic/solution` under `directory` if it holds Terraform, a Dockerfile or
    workflows.
  - `.github/dependabot.yml`: add each Terraform directory of the solution to the `terraform` entry, or a new
    `docker` entry for a Dockerfile.
  - `.github/workflows/ci.yml`: add Terraform solution directories to the `terraform` job's
    `working-directories`.
  - `pyproject.toml`: add Python dependencies to the `labs` group, then run `uv lock`.

## Verify

Grade the new lab alone, then run the full suite:

```bash
scripts/verify-labs.sh NN
make verify
```

`verify-labs.sh` prints `ok` only when the solution exits 0 and the starter exits 1 with exactly the failures in
`tests/starter-failures.txt`. Any other verdict names the problem, for example `solution does not pass`,
`starter already passes` or `starter failures differ from tests/starter-failures.txt`.
