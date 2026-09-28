terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }

  # Partial configuration: bucket, key and Region come from backend.hcl at init time,
  # so the same code serves every environment and no account detail is committed.
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project     = "harbor-goods"
      environment = var.environment
      lab         = "01-terraform-remote-state"
      managed-by  = "terraform"
    }
  }
}
