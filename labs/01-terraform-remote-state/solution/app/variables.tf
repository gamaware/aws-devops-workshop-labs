variable "environment" {
  description = "Deployment environment. Part of every parameter name and tag."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging or prod."
  }
}

variable "region" {
  description = "AWS Region for the storefront configuration."
  type        = string
  default     = "us-east-1"
}

variable "feature_flags" {
  description = "Storefront feature flags, stored as one JSON parameter."
  type        = map(bool)
  default = {
    new_checkout  = false
    gift_wrapping = true
    store_pickup  = false
  }
}
