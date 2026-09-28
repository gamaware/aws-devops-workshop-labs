terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }

  # Exercise 5: store this stack's state in the bucket from the bootstrap stack.
  # Declare an empty (partial) S3 backend here; the values go in backend.hcl.
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
