# Run the live test

`make test-live` applies the lab 01 and lab 02 solutions to a real AWS account, checks the result and destroys
everything. It is for maintainers only. It is manual: CI never runs it, and CI has no AWS credentials at all.

Run it after changes to the Terraform solutions or to the AWS provider version, since the mocked tests cannot
catch an argument that AWS rejects.

## What it proves

| Lab | Proved against the real API |
| --- | --- |
| 01 | The state bucket applies; the app stack stores its state in that bucket through the S3 backend with native locking; the SSM parameter exists |
| 02 | The queue module creates both queues, and AWS accepts the redrive policy and SSE-SQS |

Labs 03 to 05 are not deployed: lab 03 needs a bootstrapped CDK account, lab 04 a real GitHub repository and
lab 05 an ECR repository and a VPC. Their graders already run them locally.

## Before you start

- An AWS CLI profile named `dev` for the maintainer's development account. The script uses that profile and no
  other.
- Terraform, the AWS CLI v2 and a valid session for the profile.
- About five minutes. The run costs under USD 0.01 (S3 requests, SQS, a standard SSM parameter).

## Run it

```bash
make test-live
```

The script:

1. Prints `aws sts get-caller-identity` for the `dev` profile and asks for confirmation. Check the account
   before you answer `y`. Set `LIVE_YES=1` to skip the question.
2. Copies both solutions to a temporary directory outside the repository, so the lab code stays as learners see
   it.
3. Writes a `live_override.tf` file next to each stack. Terraform merges `*_override.tf` files into the
   configuration; this one sets `default_tags` with `project=harbor-goods`, the lab name,
   `managed-by=terraform`, `purpose=portfolio-test` and `run=<id>`. The run ID is the last six digits of the
   current Unix time.
4. Applies the lab 01 bootstrap with a bucket named `harbor-labs-tfstate-<id>` and `force_destroy=true`, then
   the app stack with a generated `backend.hcl` (`use_lockfile = true`, `encrypt = true`).
5. Checks that the state object and the parameter `/harbor-goods/dev/storefront/feature-flags` exist.
6. Applies the lab 02 example and reads the queue attributes `RedrivePolicy` and `SqsManagedSseEnabled`.

Set `LIVE_REGION` to use a Region other than `us-east-1`.

## Teardown

A `trap` on `EXIT` destroys the lab 02 example, the lab 01 app stack and the lab 01 bootstrap, in that order.
It runs on success, on failure and on Ctrl-C.

After the destroy, the script lists resources tagged `purpose=portfolio-test` and `run=<id>` through the
Resource Groups Tagging API. It retries six times, ten seconds apart, because deleted SQS queues stay listed for
up to a minute. Any ARN still listed ends the run with `LEFTOVER RESOURCES` and exit code 1: delete those
resources by hand.

To check for leftovers from any earlier run:

```bash
aws resourcegroupstaggingapi get-resources --profile dev --region us-east-1 \
  --tag-filters Key=purpose,Values=portfolio-test
```

## Keep the output out of the repository

The script works in a temporary directory and deletes it on exit. Its terminal output contains the account ID and
ARNs from the `dev` account. Do not paste that output into issues, pull requests, commits or documentation;
the repository uses the example account `111122223333` only.
