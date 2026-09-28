# Tooling

Versions pinned in the repository, and the checks CI runs.

## Pinned versions

| Component | Version | Pinned in |
| --- | --- | --- |
| Terraform | `>= 1.11.0, < 2.0.0`; CI uses 1.14.5 | `versions.tf` of each lab, `.github/workflows/ci.yml` |
| AWS provider | `>= 6.0, < 7.0`, locked at 6.66.0 | `versions.tf`, `.terraform.lock.hcl` in each Terraform directory |
| uv | 0.12 or later; CI installs the current release through `astral-sh/setup-uv` | `.github/workflows/ci.yml` |
| Python | 3.13, installed by uv (`requires-python` allows 3.12 or later) | `.python-version`, `pyproject.toml` |
| tflint | 0.61.0 | `.github/workflows/ci.yml` (`setup-tflint`, and `tflint-version` for the shared `terraform` workflow) |
| tflint AWS ruleset | 0.49.0 | `.tflint.hcl` |
| Checkov | 3.3.19, run through `uvx` | `Makefile` |
| Trivy | 0.74.0 | `.github/workflows/ci.yml` (`setup-trivy`) |
| Docker | Engine or Desktop 29 (the version used for verification) | Not pinned |
| aws-cdk-lib | 2.271.0 (`>= 2.271, < 3`) | `pyproject.toml`, `uv.lock` |
| constructs | 10.8.1 | `pyproject.toml`, `uv.lock` |
| cdk-nag | 3.0.2 | `pyproject.toml`, `uv.lock` |
| pytest | 9.1.1 | `pyproject.toml`, `uv.lock` |
| PyYAML | 6.0.3 | `pyproject.toml`, `uv.lock` |
| actionlint-py | 1.7.12.25 | `pyproject.toml`, `.pre-commit-config.yaml` |
| zizmor | 1.30.1 | `pyproject.toml`, `.pre-commit-config.yaml` |
| ruff | 0.16.9 | `pyproject.toml`, `uv.lock`, `.pre-commit-config.yaml` |
| Node.js | 24 in CI; 22 or 24 locally | `.github/workflows/ci.yml` |
| hadolint | 2.15.1, checked by SHA-256 in CI | `.github/workflows/ci.yml`, `.pre-commit-config.yaml` |
| Lab 05 base image | `python:3.14-slim`, pinned by digest | `labs/05-containers-to-ecs/solution/Dockerfile` |
| GitHub Actions | Pinned to full commit SHAs | `.github/workflows/*.yml`, enforced by `zizmor.yml` |

Dependabot updates GitHub Actions, the uv lock file, the lab 05 base image digest and the Terraform provider locks
weekly, after a seven-day cooldown (`.github/dependabot.yml`).

## Scanner configuration

| File | Scope |
| --- | --- |
| `.checkov.yaml` | Lab 01, 02 and 05 solutions and `.github/workflows`; Terraform, Dockerfile and GitHub Actions frameworks |
| `.semgrepignore` | Skips `labs/*/starter/`, `.venv/` and `.cache/` |
| `.tflint.hcl` | All rules of the `terraform` plugin plus the AWS ruleset |
| `zizmor.yml` | Requires a hash pin for every `uses:` |
| `.pre-commit-config.yaml` | Hygiene hooks, detect-secrets, gitleaks, markdownlint, actionlint, zizmor, shellcheck, shellharden, hadolint, ruff, Terraform fmt, validate and tflint, conventional commits |

Starters are incomplete on purpose. The scanners skip them, and `scripts/verify-labs.sh` proves that each one
fails its grader.

## CI jobs

`.github/workflows/ci.yml` runs on pull requests and on pushes to `main`. The workflow has
`permissions: {}` and each job asks for `contents: read` only: no `id-token`, no secrets, no AWS role.

| Job | What it does |
| --- | --- |
| `verify` | On `ubuntu-24.04`: installs uv, Node.js 24, Terraform 1.14.5, hadolint 2.15.1, tflint 0.61.0 and Trivy 0.74.0, then runs `make verify` |
| `lint-docs` | Reusable workflow `lint-docs.yml`: documentation linting |
| `lint-actions` | Reusable workflow `lint-actions.yml`: workflow linting |
| `secrets` | Reusable workflow `secrets.yml`: secret scanning |
| `security` | Reusable workflow `security.yml` with `checkov-config: .checkov.yaml` and `trivy-skip-dirs: labs/*/starter` |
| `terraform` | Reusable workflow `terraform.yml` on the four Terraform solution directories with Terraform 1.14.5 and tflint 0.61.0 |
| `container` | Reusable workflow `container.yml` on the lab 05 solution, image name `harbor-catalog` |

The reusable workflows live in `gamaware/.github`, pinned by commit SHA. `.github/workflows/scorecard.yml` runs the
OpenSSF Scorecard on pushes to `main` and weekly.

The `verify` job runs `make verify`, so a local run and CI execute the same targets. The shared `security` workflow
runs Checkov and Trivy a second time and adds Semgrep.
