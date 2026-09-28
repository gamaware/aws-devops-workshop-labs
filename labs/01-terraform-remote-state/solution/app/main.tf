locals {
  # One namespace per environment keeps dev and prod parameters apart.
  parameter_prefix = "/harbor-goods/${var.environment}/storefront"
}

resource "aws_ssm_parameter" "feature_flags" {
  #checkov:skip=CKV2_AWS_34:Feature flags are public configuration, not secrets; SecureString adds nothing here.
  name        = "${local.parameter_prefix}/feature-flags"
  description = "Storefront feature flags, read by the storefront at start-up."
  type        = "String"
  value       = jsonencode(var.feature_flags)
}
