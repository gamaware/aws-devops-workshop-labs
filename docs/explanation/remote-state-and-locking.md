# Remote state and locking

Lab 01 moves Terraform state from a file on one laptop into an S3 bucket. This page explains why, and what the
lab leaves out on purpose.

## Why remote state

Terraform records what it created in a state file and compares it with the code on every plan. With local
state, that record lives on the laptop of whoever ran the last apply. A second engineer, or a CI job, sees an empty
state and plans to create everything again. A lost laptop loses the only map from code to real resources.

Remote state puts one copy where every engineer and pipeline reads it, with access control, encryption and
history. For Harbor Goods, the storefront team and the release pipeline then plan against the same record.

## The bootstrap problem

The state bucket is itself infrastructure. Terraform cannot store the state of the bucket in the bucket before the
bucket exists. Lab 01 splits the work in two:

- `bootstrap` creates the bucket and keeps its own small state on local disk. It runs once per account.
- `app`, and every later stack, stores its state in that bucket.

Real engagements solve the same problem the same way, or create the state bucket from a separate account-vending
process. Either way, a small and rarely changed piece sits outside the pattern it enables.

## Locking with S3 native lock files

Two applies that run at the same time against the same state can each write a different version, and the second
write discards the first one's record. A lock prevents that: the first run takes it, the second waits or fails.

The S3 backend used to need a DynamoDB table for the lock. Terraform 1.10 added `use_lockfile`, which writes a
`.tflock` object next to the state with an S3 conditional write; Terraform 1.11 made it generally available. The
lab turns it on in `backend.hcl.example`:

```hcl
use_lockfile = true
```

The result has one fewer resource to create, secure and pay for, and the lock follows the same bucket policy as
the state. The DynamoDB option still works, but Terraform now marks it as deprecated. The lab
requires Terraform 1.11 or later for this reason.

## Partial backend configuration

`app/versions.tf` declares an empty backend:

```hcl
backend "s3" {}
```

The bucket, key, Region, encryption and locking come from `backend.hcl` at `terraform init -backend-config=...`.
The same code then serves every environment and account, and no account-specific value lands in Git: `backend.hcl`
is in `.gitignore` and Git tracks only the `.example` file.

The key `storefront/dev/terraform.tfstate` gives each stack and environment its own state object. A mistake in
`dev` then cannot overwrite the `prod` record, and plans stay small.

## State is sensitive

State holds every attribute of every resource, including values that Terraform marks as sensitive, such as
generated passwords. Treat the bucket like a secrets store. The lab bucket:

- Encrypts every object with SSE-KMS and an S3 bucket key.
- Denies any request without TLS through a bucket policy on `aws:SecureTransport`.
- Blocks public access and disables ACLs with `BucketOwnerEnforced`.
- Keeps versioning on, so a bad apply can roll back to the previous state, and expires old versions after 90
  days.

## What a real engagement adds

The lab keeps to the free tier. For Harbor Goods production, add:

- A customer managed KMS key with a key policy that names who may decrypt state, instead of the AWS managed key.
- Server access logs or CloudTrail data events on the bucket, to see who read state.
- A separate account for state, so a compromised workload account cannot rewrite its own infrastructure record.
- `lifecycle { prevent_destroy = true }` on the bucket, so a stray `terraform destroy` stops at plan time.
- IAM policies scoped per state key, so the storefront pipeline reads and writes only its own state.

See [lab 01](../../labs/01-terraform-remote-state/README.md) to build the pattern.
