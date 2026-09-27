# Grader for lab 01, part 2: the stack that keeps its state in the bucket.
# Run it through tests/run.sh (or make check LAB=01), which copies it into the configuration.

mock_provider "aws" {}

variables {
  environment = "dev"
}

run "rejects_an_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "parameters_are_namespaced_per_environment" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = aws_ssm_parameter.feature_flags.name == "/harbor-goods/prod/storefront/feature-flags"
    error_message = "The parameter name must start with /harbor-goods/<environment>/storefront/."
  }

  assert {
    condition     = jsondecode(aws_ssm_parameter.feature_flags.value)["new_checkout"] == false
    error_message = "The parameter value must be the feature flags encoded as JSON."
  }
}
