# 0002. Labs run offline by default; a sandbox account is optional

Status: Accepted

## Context

Participants arrive with different laptops, networks and permissions. Some client teams cannot create AWS accounts
before a workshop, and no workshop should need access to a client's company accounts. Live AWS steps also cost time:
account setup, quotas and cleanup can take a large share of a half-day session.

## Decision

Every graded objective runs without AWS credentials:

- Terraform labs use `terraform test` with `mock_provider`;
- the CDK lab synthesizes an environment-agnostic stack and checks it with assertions and cdk-nag;
- the OIDC lab lints the workflow with actionlint and zizmor and evaluates the trust policy against sample token
  claims (`fixtures/oidc-claims/`) with a small offline evaluator;
- the container lab builds and runs the image in local Docker under Fargate-like restrictions.

Each lab adds an optional step for a personal free-tier sandbox account, with its own cleanup.

## Alternatives

- Live labs only: stronger evidence, but setup-heavy, billable and fragile in a classroom.
- LocalStack or Moto: closer to live behavior for some services, but another tool to install and version, with gaps
  in IAM and STS behavior that matter for lab 04.

## Consequences

- Graders prove configuration intent, not AWS behavior: IAM permissions, quotas and real token exchange stay unproven
  offline. [What offline tests prove](../explanation/what-offline-tests-prove.md) states the limits for learners.
- The OIDC evaluator covers only the condition operators GitHub trust policies use; it is a teaching aid.
- `make test-live` applies the Terraform solutions to a real account by hand to close part of the gap.

## Compliance

CI runs every grader with no AWS credentials and no `id-token` permission (`.github/workflows/ci.yml`), so a lab that
needed AWS would fail there.

## Notes

The first run still downloads providers, Python packages and a base image; after that, the labs run without a
network.
