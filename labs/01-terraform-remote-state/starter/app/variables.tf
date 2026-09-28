variable "environment" {
  description = "Deployment environment. Part of every parameter name and tag."
  type        = string

  # Exercise 6: accept only dev, staging or prod.
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
