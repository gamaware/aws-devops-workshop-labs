# Usage example. It doubles as a test fixture: the grader validates it, and
# `terraform plan` here shows what the module creates.

provider "aws" {
  region = "us-east-1"
}

module "orders" {
  source = "../../modules/queue"

  name = "harbor-orders"
  tags = {
    project     = "harbor-goods"
    owner       = "platform-team"
    environment = "dev"
  }
}
