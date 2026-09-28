# The state bucket for every other stack. It is created once, with local state,
# before any stack can use the S3 backend (the "bootstrap" problem).

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18:Access logging needs a second bucket; left out to keep the lab in the free tier.
  #checkov:skip=CKV_AWS_144:Cross-Region replication doubles storage cost; versioning covers accidental overwrites.
  #checkov:skip=CKV2_AWS_62:Nothing consumes event notifications from a state bucket.
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

# Every state write keeps the previous version, so a bad apply can be rolled back.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# State files hold resource attributes, sometimes secrets: encrypt them at rest.
# The AWS managed key keeps the lab free; a real engagement uses a customer managed key.
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLs off: the bucket owner owns every object and access is decided by policy.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Refuse any request that does not use TLS.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })

  # S3 rejects a policy while the public access block is still being applied.
  depends_on = [aws_s3_bucket_public_access_block.state]
}

# Old state versions are only useful for a while; expire them to cap storage cost.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}
