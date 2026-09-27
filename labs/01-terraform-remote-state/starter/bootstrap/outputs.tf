output "bucket_name" {
  description = "Name of the state bucket."
  value       = aws_s3_bucket.state.bucket
}

# Exercise 4: add an output "backend_config" with bucket, region, encrypt = true and
# use_lockfile = true. The app stack copies these values into its backend.hcl.
