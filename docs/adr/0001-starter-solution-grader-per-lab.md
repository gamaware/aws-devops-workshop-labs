# 0001. Every lab ships a starter, a solution and a grader, and the build proves the starter needs work

Status: Accepted

## Context

Workshop labs tend to fail in two quiet ways. The solution rots: a provider or library upgrade breaks it, and nobody
notices until a room of participants hits the error. Or the starter drifts toward the solution: someone fixes a bug in
both, and the exercise no longer asks for any work. Participants also need fast, specific feedback while the
instructor helps someone else.

## Decision

Each lab directory holds `README.md` (the tutorial), `starter/` (what participants edit), `solution/` (a model answer)
and `tests/run.sh` (the grader). Every grader takes a target directory and follows one exit-code contract:

- `0`: the target meets every objective;
- `1`: the target is valid but at least one objective is not met;
- `2`: the grader cannot run: the target does not parse, or a tool is missing.

`scripts/verify-labs.sh` grades both directories of every lab and fails unless the solution exits `0` and the
untouched starter exits exactly `1`. Exit `2` on a starter also fails, so a starter cannot pass by breaking.
Participants run the same grader with `make check LAB=NN`.

The grader copies the target to a temporary directory before grading. `terraform test` accepts only a test directory
inside the configuration, and the copy keeps `.terraform`, `cdk.out` and test files out of the participant's work.

## Alternatives

- Solution only, with instructions to type it in: no feedback, and nothing proves the exercise asks for work.
- Git branches per step: hard to diff for beginners, and branches drift from `main`.
- A hosted grading service: needs accounts and network access that client workshops often cannot provide.

## Consequences

- Graders fix some names (for example resources called `state` in lab 01); each lab README states them.
- `make verify` needs every tool the labs use (Terraform, uv, Node.js, Docker, hadolint).
- A grader change is a contract change: a new check must fail on the starter and pass on the solution.

## Compliance

`make labs` and the CI `labs` job run `scripts/verify-labs.sh`. `scripts/check_docs.py` (`make docs-check`) fails when
a lab lacks `starter/`, `solution/`, an executable `tests/run.sh`, instructor notes or a required README section.

## Notes

[The grader contract reference](../reference/grader-contract.md) describes the contract for contributors.
