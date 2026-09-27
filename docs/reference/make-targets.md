# Make targets

Run `make` or `make help` to list the targets. Every target runs from the repository root and none of them, except
`test-live`, calls AWS.

## Targets

| Target | Runs |
| --- | --- |
| `help` | Lists the targets; the default goal |
| `setup` | `uv sync --frozen`: installs the locked Python environment in `.venv` |
| `verify` | `setup`, `lint`, `tflint`, `labs`, `docs-check`, `checkov` and `trivy`, in that order |
| `lint` | `ruff check`, `ruff format --check`, `terraform fmt -check -recursive labs`, `shellcheck --severity=warning` on the scripts and graders |
| `tflint` | `terraform init -backend=false` and `tflint` with `.tflint.hcl` in every Terraform directory, starters included |
| `labs` | `scripts/verify-labs.sh`: every solution must pass its grader and every starter must fail it |
| `docs-check` | `scripts/check_docs.py`: lab structure, README sections, instructor notes, relative links, placeholder markers |
| `checkov` | Checkov 3.3.19 (through `uvx`) with `.checkov.yaml` on the lab solutions and workflows |
| `trivy` | `trivy fs` misconfiguration and secret scan at HIGH and CRITICAL, skipping `labs/*/starter`, `.terraform`, `.venv` and `.cache` |
| `check` | `labs/$(LAB)-*/tests/run.sh labs/$(LAB)-*/$(TARGET)`: grades one lab |
| `reset` | `scripts/reset-lab.sh $(LAB)`: restores one starter from Git, after a confirmation |
| `test-live` | `scripts/test-live.sh`: manual, maintainers only; see [run the live test](../how-to/run-the-live-test.md) |
| `clean` | Removes `.cache` and every `.terraform`, `cdk.out` and `__pycache__` under `labs`; keeps `.venv` |

## Variables

| Name | Kind | Default | Used by | Effect |
| --- | --- | --- | --- | --- |
| `LAB` | make variable | empty | `check`, `reset` | Two-digit lab number, for example `LAB=03`; required |
| `TARGET` | make variable | `starter` | `check` | `starter` or `solution` |
| `RESET_YES` | environment | `0` | `reset` | `1` skips the confirmation |
| `LIVE_YES` | environment | `0` | `test-live` | `1` skips the confirmation |
| `LIVE_REGION` | environment | `us-east-1` | `test-live` | Region for the live test |

## Examples

```bash
make check LAB=02
make check LAB=02 TARGET=solution
RESET_YES=1 make reset LAB=02
```

`make reset` discards tracked changes and deletes untracked and ignored files under the starter, including
`terraform.tfvars`, `backend.hcl` and local Terraform state. It does not touch AWS.
