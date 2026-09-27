# 0004. One locked Python environment for the CDK lab and the graders

Status: Accepted

## Context

Lab 03 needs `aws-cdk-lib`, `constructs` and `cdk-nag`; the graders for labs 03 to 05 need `pytest`, `pyyaml`,
`actionlint` and `zizmor`. Per-lab virtual environments and `pip install -r` files drift apart, and a workshop loses
time when one participant resolves a different version.

## Decision

The repository has one `pyproject.toml` and one `uv.lock`. `make setup` runs `uv sync --frozen`, and graders call
`uv run --frozen`. actionlint and zizmor come from PyPI wheels (`actionlint-py`, `zizmor`), so participants do not
install them separately. Dependabot updates the lock file weekly.

## Alternatives

- `requirements.txt` per lab: simple, but no lock and no shared resolution.
- System-wide tools: versions differ per laptop, and graders give different answers.

## Consequences

- Participants install `uv`; it downloads a matching Python when needed.
- aws-cdk-lib runs on Node.js through jsii, so Node.js stays a prerequisite for lab 03.

## Compliance

`uv run --frozen` fails when `pyproject.toml` and `uv.lock` disagree. CI installs from the lock file only.

## Notes

The CDK CLI is optional: the graders synthesize through the Python library, and `npx aws-cdk@2` covers ad hoc use.
