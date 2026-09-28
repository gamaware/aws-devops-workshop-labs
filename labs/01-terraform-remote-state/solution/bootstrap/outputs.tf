output "bucket_name" {
  description = "Name of the state bucket."
  value       = aws_s3_bucket.state.bucket
}

output "backend_config" {
  description = "Settings for the partial S3 backend configuration of every stack that stores its state here."
  value = {
    bucket       = aws_s3_bucket.state.bucket
    region       = var.region
    encrypt      = true
    use_lockfile = true
  }
}
