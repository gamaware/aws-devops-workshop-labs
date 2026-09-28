# Changelog

This file records all notable changes to this project. The format follows
[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Lab 01: Terraform fundamentals and the remote-state pattern (hardened S3 state bucket, partial S3 backend with
  native locking), graded with mocked `terraform test`.
- Lab 02: an SQS queue module with a dead-letter queue, input validation and the participant's own
  `terraform test` suite.
- Lab 03: AWS CDK in Python with template assertions and cdk-nag AWS Solutions checks.
- Lab 04: GitHub Actions to AWS with OIDC, graded with actionlint, zizmor and an offline trust-policy dry run
  against sample token claims.
- Lab 05: a hardened container image run read-only without capabilities, and a Fargate task definition review.
- Grader contract (exit 0, 1, 2) and `scripts/verify-labs.sh`, which proves every solution passes and every starter
  fails.
- Instructor guide, half-day agendas, notes per lab and a mentoring notes template.
- Diátaxis docs (how-to, reference, explanation), four ADRs, three diagrams and a 1280x640 social preview.
- CI (`make` targets plus the shared gamaware/.github workflows), Dependabot and OpenSSF Scorecard.
- `make test-live`: a manual end-to-end test of the Terraform solutions against the maintainer's account.

### Changed

- Lab 04 publishes the storefront's static assets (a maintenance page) to the `harbor-goods-storefront-static`
  bucket; the storefront itself runs on ECS Fargate, as in the other Harbor Goods samples.
- `scripts/verify-labs.sh` compares each starter's failures with `tests/starter-failures.txt`, read from the
  grader's full report (`GRADER_REPORT`) rather than its shortened console output.

### Fixed

- Graders treat a missing or crashing tool, a pytest collection error or a skipped test as a hard error (exit 2)
  instead of a failed objective.
- `make setup` creates the Terraform provider cache directory, so `terraform fmt` in CI no longer warns about it.
- CI caller jobs use the shared check names (`verify`, `lint-docs`, `lint-actions`, `secrets`, `security`,
  `terraform`, `container`).

### Security

- CI calls the shared reusable workflows from `gamaware/.github` pinned to a full commit SHA.
