# The module's own tests: fast, mocked, and run with `terraform test` from modules/queue.
#
# Exercise 9: add at least two more run blocks. One of them must use expect_failures
# to prove that a validation rejects bad input, for example max_receive_count = 11.

mock_provider "aws" {}

variables {
  name = "harbor-orders"
  tags = {
    owner       = "platform-team"
    environment = "dev"
  }
}

run "queue_uses_the_given_name" {
  command = plan

  assert {
    condition     = aws_sqs_queue.this.name == "harbor-orders"
    error_message = "The main queue must use var.name."
  }
}
