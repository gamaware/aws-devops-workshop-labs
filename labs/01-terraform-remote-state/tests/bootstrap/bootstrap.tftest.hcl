# Grader for lab 01, part 1: the state bucket. Runs against a mocked AWS
# provider, so no credentials are needed and nothing is created.
# Run it through tests/run.sh (or make check LAB=01), which copies it into the configuration.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::harbor-goods-tfstate-example"
    }
  }
}

variables {
  bucket_name = "harbor-goods-tfstate-example"
}

run "rejects_an_invalid_bucket_name" {
  command = plan

  variables {
    bucket_name = "Harbor_Goods_State"
  }

  expect_failures = [var.bucket_name]
}

run "state_bucket_is_hardened" {
  command = apply

  assert {
    condition     = var.force_destroy == false && aws_s3_bucket.state.force_destroy == false
    error_message = "By default, destroy must refuse to delete a bucket that still holds state."
  }

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be enabled so an overwritten state file can be recovered."
  }

  assert {
    condition = anytrue([
      for rule in aws_s3_bucket_server_side_encryption_configuration.state.rule :
      rule.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms" && rule.bucket_key_enabled == true
    ])
    error_message = "State must be encrypted with SSE-KMS and an S3 Bucket Key."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.state.block_public_acls,
      aws_s3_bucket_public_access_block.state.block_public_policy,
      aws_s3_bucket_public_access_block.state.ignore_public_acls,
      aws_s3_bucket_public_access_block.state.restrict_public_buckets,
    ])
    error_message = "All four public access block settings must be true."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.state.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled (BucketOwnerEnforced)."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_s3_bucket_policy.state.policy).Statement :
      statement.Effect == "Deny" && tostring(try(statement.Condition.Bool["aws:SecureTransport"], "")) == "false"
    ])
    error_message = "The bucket policy must deny requests that do not use TLS (aws:SecureTransport = false)."
  }

  assert {
    condition = anytrue([
      for rule in aws_s3_bucket_lifecycle_configuration.state.rule :
      rule.status == "Enabled" && length(rule.noncurrent_version_expiration) > 0
    ])
    error_message = "A lifecycle rule must expire noncurrent state versions."
  }
}

run "exposes_the_backend_settings" {
  command = apply

  assert {
    condition     = output.backend_config.bucket == "harbor-goods-tfstate-example"
    error_message = "backend_config.bucket must be the state bucket name."
  }

  assert {
    condition     = output.backend_config.use_lockfile == true && output.backend_config.encrypt == true
    error_message = "backend_config must turn on S3 native locking (use_lockfile) and encryption."
  }
}
