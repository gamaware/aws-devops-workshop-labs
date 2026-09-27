variable "bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state. S3 bucket names are global: add your initials or account ID."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Use 3 to 63 lowercase letters, digits or hyphens, starting and ending with a letter or digit."
  }
}

variable "region" {
  description = "AWS Region for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a bucket that still holds state versions. Set to true only to reset the lab."
  type        = bool
  default     = false
}
