# Lab 01: Terraform fundamentals and the remote-state pattern

Create a shared S3 bucket for your team's Terraform state, then migrate a second stack's state to that bucket using S3
native locking.

## Objectives

After completing the lab, you can:

- assemble a root module that includes variables, validation, locals, resources and outputs;
- secure an S3 state bucket with versioning, SSE-KMS, a public access block, a TLS-only policy and lifecycle rules;
- configure a partial S3 backend using settings supplied through a `backend.hcl` file;
- describe how `use_lockfile = true` prevents two engineers from applying simultaneously;
- run `terraform test` with a mocked AWS provider to test a configuration.

## Prerequisites

- Install Terraform 1.11 or later and `make`; this repository uses 1.14.5. Follow
  [set up your machine](../../docs/how-to/set-up-your-machine.md).
- You need basic command-line skills, but no prior experience with Terraform.
- You can complete the lab without an AWS account. For the optional sandbox step, you need one; follow
  [use a sandbox account](../../docs/how-to/use-a-sandbox-account.md).

## Duration

Allow 60 to 75 minutes for the lab and another 15 minutes if you take the optional sandbox step.

## Scenario

At Harbor Goods, two engineers each run Terraform on a laptop and maintain a local `terraform.tfstate`. An apply using
one engineer's outdated state once deleted a parameter required by the storefront. The team now wants a shared state
bucket with encryption, versioning and locking, plus a storefront stack that stores its state in that bucket.

You work with two stacks in this lab:

| Stack | Directory | State |
| --- | --- | --- |
| Bootstrap | `starter/bootstrap/` | Local. It creates the bucket that every other stack uses. |
| App | `starter/app/` | Remote, in the bootstrap bucket. It stores storefront feature flags in Parameter Store. |

## Steps

Use `starter/` as your working directory. Follow the numbered `Exercise` comments in its files alongside the
corresponding steps below.

1. Review the starter files, then run the grader to learn what it checks:

   ```bash
   make check LAB=01
   ```

   The `FAIL` lines identify what you need to complete. A `RESULT ... not met` message means your tools are working.

2. **Check the bucket name** (`bootstrap/variables.tf`, exercise 1). Define a `validation` block requiring 3 to 63
   lowercase letters, digits or hyphens, with a letter or digit at both ends. Use a `regex` within `can()`.

3. **Require deliberate teardown** (exercise 2). Define `force_destroy` as a `bool` variable with a `false` default,
   then pass it to the bucket so an accidental `terraform destroy` leaves a bucket containing state versions intact.

4. **Secure the bucket** (`bootstrap/main.tf`, exercise 3). For every resource type listed below, create one resource
   named `state`:

   | Resource | Setting |
   | --- | --- |
   | `aws_s3_bucket_versioning` | `status = "Enabled"` |
   | `aws_s3_bucket_server_side_encryption_configuration` | `sse_algorithm = "aws:kms"`, `bucket_key_enabled = true` |
   | `aws_s3_bucket_public_access_block` | all four settings `true` |
   | `aws_s3_bucket_ownership_controls` | `object_ownership = "BucketOwnerEnforced"` |
   | `aws_s3_bucket_policy` | deny `s3:*` when `aws:SecureTransport` is `"false"` |
   | `aws_s3_bucket_lifecycle_configuration` | expire noncurrent versions after 90 days |

   Use `jsonencode()` to define the policy. Because the tests' mocked provider generates invented output for an
   `aws_iam_policy_document` data source, the grader cannot verify a policy from that source offline.

5. **Expose the backend settings** (`bootstrap/outputs.tf`, exercise 4). Define an output named `backend_config`
   containing `bucket`, `region`, `encrypt = true` and `use_lockfile = true`.

6. **Set up the backend declaration** (`app/versions.tf`, exercise 5). Place an empty `backend "s3" {}` block within
   `terraform`. This partial configuration lets you keep the bucket name and account details outside the code.

7. **Check the environment value** (`app/variables.tf`, exercise 6). Restrict accepted values to `dev`, `staging` and
   `prod`.

8. **Give parameters a namespace** (`app/main.tf`, exercise 7). Define `/harbor-goods/<environment>/storefront` in a
   `local`, then include it in the parameter name to prevent collisions between dev and prod.

9. **Fill in `app/backend.hcl.example`** (exercise 8). Set `key = "storefront/dev/terraform.tfstate"`, `encrypt = true`
   and `use_lockfile = true`.

10. Rerun the grader as you complete the work, until all lines show `PASS`:

    ```bash
    make check LAB=01
    ```

### Optional: try it in a sandbox account

Set your sandbox profile with `export AWS_PROFILE=...`, then apply the bootstrap using local state. Next, configure the
app to use the bucket:

```bash
cd labs/01-terraform-remote-state/starter/bootstrap
cp terraform.tfvars.example terraform.tfvars   # make the bucket name unique
terraform init && terraform apply
terraform output backend_config

cd ../app
cp backend.hcl.example backend.hcl             # use the bucket name from the output
terraform init -backend-config=backend.hcl
terraform apply -var environment=dev
```

During the app's apply, list the bucket's contents from another terminal. You will see
`storefront/dev/terraform.tfstate.tflock` appear and then disappear; this object serves as the lock.

## Expected result

You have completed the checks when `make check LAB=01` finishes with `RESULT all objectives met` and each check shows
`PASS`:

```text
PASS   bootstrap: state bucket is versioned, encrypted, private and TLS-only
PASS   app: environment is validated and parameters are namespaced
PASS   app: declares a partial S3 backend
PASS   app: backend.hcl.example turns on S3 native locking
PASS   app: backend.hcl.example turns on encryption
PASS   app: backend.hcl.example keeps one state key per stack and environment
```

Review [`solution/`](solution/) against your work, and find the tests the grader runs in [`tests/`](tests/).

## Reset

If you applied resources in a sandbox account, destroy those resources first. Start with the app, then destroy the
bootstrap:

```bash
terraform -chdir=labs/01-terraform-remote-state/starter/app destroy -var environment=dev
terraform -chdir=labs/01-terraform-remote-state/starter/bootstrap apply -var force_destroy=true
terraform -chdir=labs/01-terraform-remote-state/starter/bootstrap destroy -var force_destroy=true
```

Afterward, restore the starter files, discarding your edits:

```bash
make reset LAB=01
```

## Going further

- What explains the state bucket's use of local state? How would you handle that local state file?
- Consult [remote state and locking](../../docs/explanation/remote-state-and-locking.md) to learn what a production
  state setup adds: a customer managed KMS key, access logs, a separate state account and `prevent_destroy`.
