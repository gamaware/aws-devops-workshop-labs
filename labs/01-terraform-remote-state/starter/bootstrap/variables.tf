variable "bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state. S3 bucket names are global: add your initials or account ID."
  type        = string

  # Exercise 1: add a validation block. Accept 3 to 63 lowercase letters, digits or
  # hyphens that start and end with a letter or digit.
}

variable "region" {
  description = "AWS Region for the state bucket."
  type        = string
  default     = "us-east-1"
}

# Exercise 2: add a bool variable "force_destroy" (default false) and pass it to the bucket.
