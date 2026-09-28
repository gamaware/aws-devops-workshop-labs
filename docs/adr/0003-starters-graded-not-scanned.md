# 0003. Graders check the starters; scanners skip them

## Status

Accepted

## Context

Starters are insecure or incomplete on purpose: a public-by-default bucket, stored AWS keys, a root container, a
privileged task. Repository scanners (Checkov, Trivy, Semgrep, hadolint) would report those findings on every pull
request. Silencing the rules for the whole repository would also hide real problems in the solutions, which are the
model answers participants copy.

## Decision

Scanners skip `labs/*/starter/` by path and scan everything else in full:

- Checkov scans the solution directories listed in `.checkov.yaml`;
- Trivy runs with `--skip-dirs 'labs/*/starter'` (`make trivy` and the shared security workflow);
- Semgrep reads `.semgrepignore`;
- the hadolint pre-commit hook excludes starters.

The configuration disables no rule globally; one inline skip in a solution carries its reason (see Notes). The
graders check the same issues instead (for example unpinned actions, root users, missing encryption).
`scripts/verify-labs.sh` checks that each solution passes and each starter fails, and compares the starter's failed
objectives and grader tests with the list in `labs/NN-*/tests/starter-failures.txt`, so a grader that stops
detecting a planted issue fails the build. Linters that the starters pass, such as tflint, actionlint and
`terraform validate`, still run on them.

## Consequences

- Scanners stay silent about a security regression in a starter on purpose: the starter is the problem
  statement.
- A regression in a solution fails CI.

## Compliance

`make checkov` and `make trivy` in `make verify`; the shared `security` workflow in CI with `checkov-config` and
`trivy-skip-dirs` set; `make labs` for the starters.

## Notes

The one remaining skip in the solutions carries its reason next to the resource, for example the AWS managed key on
the lab 01 state bucket (`#trivy:ignore:AVD-AWS-0132`).

Alternatives considered:

- Inline skip comments in every starter file: noisy, and they teach participants to suppress findings.
- A baseline of accepted findings: drifts as scanners add rules, and hides the intent.
