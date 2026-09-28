output "feature_flags_parameter" {
  description = "Name of the SSM parameter that holds the feature flags."
  value       = aws_ssm_parameter.feature_flags.name
}
