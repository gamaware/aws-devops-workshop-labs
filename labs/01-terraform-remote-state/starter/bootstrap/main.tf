# The state bucket for every other stack. It is created once, with local state,
# before any stack can use the S3 backend (the "bootstrap" problem).
#
# Exercise 3: harden the bucket. Add these resources, each named "state":
#   - aws_s3_bucket_versioning: status Enabled
#   - aws_s3_bucket_server_side_encryption_configuration: aws:kms with the S3 Bucket Key on
#   - aws_s3_bucket_public_access_block: all four settings true
#   - aws_s3_bucket_ownership_controls: BucketOwnerEnforced
#   - aws_s3_bucket_policy: deny s3:* when aws:SecureTransport is false (write it with jsonencode)
#   - aws_s3_bucket_lifecycle_configuration: expire noncurrent versions after 90 days

resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name
}
