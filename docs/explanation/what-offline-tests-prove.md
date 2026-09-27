# What the offline tests prove

Every lab grader runs without AWS credentials. That keeps the workshop free, safe and repeatable, and lets CI
grade every lab on every pull request. It also means the graders prove some things and not others. This page draws
that line.

## Terraform tests with a mocked provider

Labs 01 and 02 use `terraform test` with `mock_provider "aws"`. Each `run` block either plans or applies against
the mock, which fills computed attributes such as ARNs with placeholder values.

What they prove:

- The configuration parses, initializes and validates against the real provider schema.
- Variable validations reject bad input. `expect_failures` tests show that an unknown environment or a receive
  count of zero fails at plan time.
- The plan sets the arguments that matter: versioning, encryption, the public access block, the TLS-only policy,
  the redrive policy and tags.

What they cannot prove:

- That AWS accepts the values. A mocked provider returns placeholder values and never calls the API, so an invalid
  argument combination only fails on a real apply.
- That the caller has the IAM permissions to create the resources.
- Service quotas, name collisions such as a taken S3 bucket name, and Region availability.
- That the S3 backend and its lock file work, since the grader runs `terraform init -backend=false`.

## CDK assertions and cdk-nag

Lab 03 synthesizes the stack to a CloudFormation template and inspects it with `aws_cdk.assertions` and the
cdk-nag AWS Solutions rules.

What they prove:

- The template contains the resources and properties the tests assert: encryption, blocked public access,
  versioning, access logs, TLS-only policies and `DeletionPolicy: Retain`.
- The stack passes the AWS Solutions rule pack, and every acknowledged rule carries a reason.

What they cannot prove:

- That CloudFormation deploys the template: resource limits, name conflicts and account-level settings only show up
  in a deploy.
- Anything about the bootstrap stack or the deploy role the CDK CLI uses.

## actionlint, zizmor and the OIDC dry run

Lab 04 checks the workflow with actionlint and zizmor, then evaluates the IAM trust policy against sample token
claims in `fixtures/oidc-claims/` with `tests/oidc_dry_run.py`.

What they prove:

- The workflow is valid syntax, pins every action to a commit SHA and requests `id-token: write` only in the
  deploy job.
- The trust policy admits the `push-main-production` claims and rejects pull requests, feature branches, other
  repositories, the staging environment and a wrong audience.
- The deploy policy stays on the site bucket.

What they cannot prove:

- A real token exchange. The dry run implements the subset of IAM condition logic that GitHub trust policies use;
  it does not replace IAM Access Analyzer or a real `AssumeRoleWithWebIdentity` call.
- That the OIDC provider exists in the account, or that the GitHub environment and its protection rules exist.

## Docker smoke test

Lab 05 builds the image and runs it the way Fargate will: `--read-only`, `--cap-drop ALL`,
`--security-opt no-new-privileges`. It then waits for the health check and calls `GET /products`.

What it proves:

- The image runs as a non-root user without pip, starts on a read-only root file system and turns healthy.
- The task definition sets the fields in the hardening checklist.

What it cannot prove:

- That ECS pulls the image from ECR, that the execution role can read the secret and write logs, or that the
  service reaches a steady state behind a load balancer.
- Networking: subnets, security groups and routes to ECR and CloudWatch Logs.

## Closing the gap

Two paths cover what the offline graders cannot:

- Learners deploy their own work to a personal account with [use a sandbox account](../how-to/use-a-sandbox-account.md).
- Maintainers apply the Terraform solutions to a development account with
  [run the live test](../how-to/run-the-live-test.md), after provider or solution changes.
