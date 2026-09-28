# Exercise 7: dev and prod share one account in this lab, so their parameters collide.
# Build the name from a local, "/harbor-goods/<environment>/storefront", and use it below.

resource "aws_ssm_parameter" "feature_flags" {
  #checkov:skip=CKV2_AWS_34:Feature flags are public configuration, not secrets; SecureString adds nothing here.
  name        = "/storefront/feature-flags"
  description = "Storefront feature flags, read by the storefront at start-up."
  type        = "String"
  value       = jsonencode(var.feature_flags)
}
