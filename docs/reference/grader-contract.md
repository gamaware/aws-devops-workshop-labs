# Grader contract

Each lab has a grader at `labs/NN-*/tests/run.sh`. It takes one argument, the directory to grade:

```bash
labs/01-terraform-remote-state/tests/run.sh labs/01-terraform-remote-state/starter
```

`make check LAB=NN [TARGET=starter|solution]` calls it for you.

## Exit codes

| Code | Meaning | Expected for |
| --- | --- | --- |
| 0 | The target meets every objective | The solution |
| 1 | The target is valid, but at least one objective is not met | The untouched starter |
| 2 | The target does not initialize or a tool is missing: the grader cannot run | Nothing |

`scripts/verify-labs.sh` relies on these codes: it fails the build unless each solution exits 0 and each starter
exits 1.

## Output lines

| Prefix | Source | Effect |
| --- | --- | --- |
| `ok` | `setup` passed | None |
| `BROKEN` | `setup` failed | Prints the last 40 log lines and exits 2 at once |
| `PASS` | `check` passed | None |
| `FAIL` | `check` failed | Prints the last 40 log lines and counts one failure; grading continues |
| `SETUP  missing tool:` | `require_tool` | Exits 2 at once |
| `RESULT` | `finish` | Exits 1 if any `check` failed, else 0 |

## Helpers in `scripts/lib/grader.sh`

| Helper | Purpose |
| --- | --- |
| `resolve_target DIR` | Prints the absolute path of `DIR`, or exits 2 with a usage line |
| `require_tool NAME...` | Exits 2 when a tool is not on `PATH` |
| `setup DESCRIPTION COMMAND...` | A precondition; a failure stops the grader with exit 2 |
| `check DESCRIPTION COMMAND...` | One objective; `finish` counts the failures |
| `tf_init DIR` | `terraform init -backend=false -input=false`: no backend, no credentials |
| `tf_test DIR TESTS_DIR` | Copies `TESTS_DIR/*.tftest.hcl` into `DIR/grader/` and runs `terraform test -test-directory=grader` |
| `finish` | Prints `RESULT` and exits with the contract code |

## Working copy

Every grader copies the target into `$GRADER_WORK`, a temporary directory removed on exit, and grades the copy.

- `terraform test` only accepts a test directory inside the configuration. Copying lets the grader add its own
  `.tftest.hcl` files next to the learner's code.
- The learner's directory stays clean: no `grader/` directory, `.terraform`, `cdk.out` or image build output
  appears in it.

## Environment

| Variable | Value | Why |
| --- | --- | --- |
| `TF_PLUGIN_CACHE_DIR` | `.cache/terraform-plugins` in the repository, unless already set | Providers download once and serve every lab |
| `TF_IN_AUTOMATION` | `1` | Shorter Terraform output |
| `CHECKPOINT_DISABLE` | `1` | No HashiCorp version check call |
| `JSII_SILENCE_WARNING_UNTESTED_NODE_VERSION` | `1` | No jsii warning on newer Node.js releases |

## What each grader checks

### Lab 01: Terraform remote state

Tools: `terraform`.

| Kind | Line |
| --- | --- |
| setup | `bootstrap: terraform init` |
| setup | `bootstrap: terraform validate` |
| setup | `app: terraform init` |
| setup | `app: terraform validate` |
| check | `bootstrap: state bucket is versioned, encrypted, private and TLS-only` |
| check | `app: environment is validated and parameters are namespaced` |
| check | `app: declares a partial S3 backend` |
| check | `app: backend.hcl.example turns on S3 native locking` |
| check | `app: backend.hcl.example turns on encryption` |
| check | `app: backend.hcl.example keeps one state key per stack and environment` |

### Lab 02: Terraform module testing

Tools: `terraform`.

| Kind | Line |
| --- | --- |
| setup | `modules/queue: terraform init` |
| setup | `modules/queue: terraform validate` |
| setup | `examples/basic: terraform init` |
| setup | `examples/basic: terraform validate` |
| check | `module: the learner's own terraform test suite passes` |
| check | `module: the own suite has 3+ run blocks, including an expect_failures test` |
| check | `module: validations, dead-letter queue, encryption and outputs meet the contract` |

### Lab 03: CDK in Python with assertions

Tools: `uv`, `node`.

| Kind | Line |
| --- | --- |
| setup | `the stack synthesizes (without cdk-nag)` |
| check | `own tests: the learner's assertion tests pass` |
| check | `own tests: 3 or more assertion tests` |
| check | `cdk-nag passes and the template keeps data private, encrypted and retained` |

### Lab 04: GitHub Actions with OIDC

Tools: `uv`.

| Kind | Line |
| --- | --- |
| setup | `workflow is valid GitHub Actions syntax (actionlint)` |
| setup | `IAM policies are valid JSON` |
| setup | `deploy policy is valid JSON` |
| check | `workflow passes zizmor's security audit (offline)` |
| check | `workflow uses OIDC, SHA pins, least privilege; trust and deploy policies are tight` |

The last check runs the trust policy through `tests/oidc_dry_run.py` against every claims file in
`fixtures/oidc-claims/`.

### Lab 05: Containers to ECS

Tools: `uv`, `python3`, `docker`, `hadolint`, `curl`.

| Kind | Line |
| --- | --- |
| setup | `Docker daemon is running` |
| setup | `the app compiles` |
| setup | `task definition is valid JSON` |
| check | `Dockerfile passes hadolint` |
| check | `image and task definition follow the Fargate hardening checklist` |
| check | `image has no pip, runs read-only as non-root without capabilities, turns healthy, serves /products` |

The last check runs `tests/smoke.sh`, which builds the image and runs it with `--read-only`, `--cap-drop ALL`
and `--security-opt no-new-privileges`.
