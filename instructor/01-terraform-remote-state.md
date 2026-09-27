# Lab 01 instructor notes: Terraform remote state

Lab directory: [labs/01-terraform-remote-state](../labs/01-terraform-remote-state/). Background reading for you:
[docs/explanation](../docs/explanation/).

## Timing

Suggested duration: 85 minutes.

| Part | Minutes |
| --- | --- |
| Brief | 5 |
| Opening demo | 5 |
| Work time | 60 |
| Debrief | 15 |

In a 1:1 session, plan exercises 1 to 5 for the session and 6 to 8 as practice.

## Learning goals

By the end, participants can:

- Explain why a team cannot share local state and what the "bootstrap" problem is.
- Harden a state bucket: versioning, SSE-KMS with an S3 Bucket Key, public access block, ACLs off, TLS-only policy,
  and a lifecycle rule for old versions.
- Declare a partial S3 backend and pass the bucket, key, encryption and S3 native locking at `terraform init`.
- Validate input variables and namespace resources per environment.
- Read `terraform test` output that runs against a mocked AWS provider.

## Opening demo (5 minutes)

1. Run `make check LAB=01` on the untouched starter. Point at the four `ok` lines (init and validate for both
   stacks) and the six `FAIL` lines. Read `RESULT 6 objective(s) not met` aloud: this is the expected start.
2. Open `tests/bootstrap/bootstrap.tftest.hcl` and show `mock_provider "aws" {}`. Nothing reaches AWS; that is why
   nobody needs credentials.
3. Show the three run blocks in that file and the `skip` lines in the grader output. Explain that when a run block
   fails, Terraform skips the rest of the file, so exercise 1 unlocks the feedback for exercises 2 to 4.
4. Open `starter/bootstrap/main.tf` and read the Exercise 3 comment. Tell the group to name every new resource
   `state`.

## Exercise map

| Exercise | File | Grader check | Run block or test |
| --- | --- | --- | --- |
| 1: bucket name validation | `bootstrap/variables.tf` | `bootstrap: state bucket is versioned, encrypted, private and TLS-only` | `rejects_an_invalid_bucket_name` |
| 2: `force_destroy` variable | `bootstrap/variables.tf`, `main.tf` | same check | `state_bucket_is_hardened` (first assertion) |
| 3: harden the bucket | `bootstrap/main.tf` | same check | `state_bucket_is_hardened` |
| 4: `backend_config` output | `bootstrap/outputs.tf` | same check | `exposes_the_backend_settings` |
| 5: partial S3 backend | `app/versions.tf` | `app: declares a partial S3 backend` | grep for `backend "s3" {}` |
| 6: environment validation | `app/variables.tf` | `app: environment is validated and parameters are namespaced` | `rejects_an_unknown_environment` |
| 7: per-environment name | `app/main.tf` | same check | `parameters_are_namespaced_per_environment` |
| 8: backend settings | `app/backend.hcl.example` | the three `app: backend.hcl.example ...` checks | `use_lockfile`, `encrypt`, `key` lines |

The assertion for exercise 2 also passes when the variable is missing, because the provider default for
`force_destroy` is `false`. Check exercise 2 by eye in the debrief; the sandbox cleanup depends on it.

## Common mistakes

**Work on exercise 3 first, see no progress.** The first run block tests exercise 1, and Terraform skips every
later run block in the file after a failure:

```text
  run "rejects_an_invalid_bucket_name"... fail
Error: Missing expected failure
  run "state_bucket_is_hardened"... skip
  run "exposes_the_backend_settings"... skip
```

Tell the participant to finish exercise 1 first. The same applies to the app file: exercise 6 unlocks exercise 7.

**Bucket policy built with the `aws_iam_policy_document` data source.** This works against real AWS, but under
the mocked provider the data source returns a random string for `json`, so the policy is not JSON:

```text
Error: "policy" contains an invalid JSON: invalid character 'i' after top-level value
  with aws_s3_bucket_policy.state,
```

The Exercise 3 comment asks for `jsonencode`. Use it; the debrief can cover when a data source is the better choice.

**Resource names other than `state`.** The grader addresses `aws_s3_bucket_versioning.state` and the others by
name:

```text
Error: Reference to undeclared resource
A managed resource "aws_s3_bucket_versioning" "state" has not been declared
in the root module.
```

**Backend block with content, or split over lines.** The check greps `versions.tf` for `backend "s3" {}` on one
line. A block with `bucket = ...` inside fails `app: declares a partial S3 backend`, and it also defeats the
purpose: the values belong in `backend.hcl`.

**Edits in `backend.hcl` instead of `backend.hcl.example`.** The grader reads `backend.hcl.example`. The real
`backend.hcl` is in `.gitignore`, so it never reaches the repository. Values must sit alone on their line: a
trailing comment after `use_lockfile = true` fails the check.

**Wrong state key.** The key check expects exactly `key = "storefront/dev/terraform.tfstate"`. Keys like
`dev/storefront.tfstate` fail `keeps one state key per stack and environment`.

**DynamoDB lock table.** Participants with older Terraform habits add `dynamodb_table`. Terraform 1.11 and later
lock with `use_lockfile = true` in S3 itself; the grader expects that setting.

## Debrief questions

1. Why does the bootstrap stack keep local state, and where would you keep that state file in a team?
2. What does versioning protect against that encryption does not, and the other way round?
3. Why is the backend partial? What would go wrong if the bucket name sat in `versions.tf`?
4. Two environments share one account in this lab. What changes if dev and prod live in separate accounts?
5. The tests run against a mocked provider. What can a mocked test prove, and what can it not?

## Stretch goals

- Add a `staging` backend file with its own key and explain how `terraform init -reconfigure` switches between
  them.
- Add an assertion to your own copy of the bootstrap test that the lifecycle rule also aborts incomplete multipart
  uploads.
- Replace the AWS managed key with a customer managed KMS key and a key policy, and discuss the cost.

## If you have a sandbox

Optional, instructor or participant, in a sandbox account only (see
[Use a sandbox account](../docs/how-to/use-a-sandbox-account.md)). Use the solution or a passing starter.

```bash
cd labs/01-terraform-remote-state/starter/bootstrap
cp terraform.tfvars.example terraform.tfvars   # set a unique bucket_name
terraform init && terraform apply
terraform output backend_config

cd ../app
cp backend.hcl.example backend.hcl             # set bucket to the output above
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl && terraform apply
```

Show the state object in the bucket and its versions after a second apply with a changed feature flag.

Cleanup, in this order:

```bash
cd labs/01-terraform-remote-state/starter/app && terraform destroy
cd ../bootstrap
terraform apply -var force_destroy=true         # let destroy delete the remaining state versions
terraform destroy -var force_destroy=true
```

Then run `make reset LAB=01` if the participant wants a clean starter.
