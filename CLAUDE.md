# CLAUDE.md: aws-devops-workshop-labs

Teaching labs for AWS, Terraform, CDK and CI/CD workshops. Fictional client "Harbor Goods". Offline verification
only; never run anything against AWS from this repo except `make test-live`, which the maintainer runs by hand.

## Layout

- `labs/NN-topic/`: `README.md` (tutorial), `starter/` (exercise), `solution/` (model answer), `tests/run.sh` (grader).
- `scripts/lib/grader.sh`: shared grader helpers and the exit-code contract (0 met, 1 not met, 2 broken).
- `scripts/verify-labs.sh`: every solution must exit 0 and every untouched starter must exit 1 with exactly the
  failures in `labs/NN-*/tests/starter-failures.txt`.
- `fixtures/oidc-claims/`: sample GitHub OIDC claims for the lab 04 dry run.
- `instructor/`, `docs/{how-to,reference,explanation,adr,diagrams}/`.

## Commands

- `make verify`: the CI verify job (lint, tflint, lab grading, docs check, Checkov, Trivy); the shared workflows in
  `ci.yml` add link checks, Vale, Semgrep, gitleaks and the container build.
- `make check LAB=NN [TARGET=starter|solution]`: grade one lab. `make reset LAB=NN`: restore a starter.
- `make test-live`: manual, `dev` profile, tags `purpose=portfolio-test`, destroys on exit.

## Rules

- Conventional commits on a feature branch; never commit to `main`. No AI attribution anywhere.
- A new grader check must pass on the solution and fail on the starter; run `scripts/verify-labs.sh NN`.
- Starters are graded, not scanned (ADR 0003): keep scanner exclusions limited to `labs/*/starter/`.
- Solution skips (Checkov, Trivy) sit next to the resource with their reason. No blanket skips.
- Lab READMEs keep the sections Objectives, Prerequisites, Duration, Scenario, Steps, Expected result, Reset, in order
  (`make docs-check`).
- Only AWS documentation example account IDs (`111122223333`) and `example.com`; no real IDs, ARNs, IPs or emails.
- Python dependencies change through `uv add` / `uv lock`, never by editing `uv.lock`.
- Diagrams: edit the `.drawio` source, then export SVG and PNG.
