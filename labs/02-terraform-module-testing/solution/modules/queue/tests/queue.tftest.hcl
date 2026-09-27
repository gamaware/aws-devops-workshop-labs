# The module's own tests: fast, mocked, and run with `terraform test` from modules/queue.

mock_provider "aws" {}

variables {
  name = "harbor-orders"
  tags = {
    owner       = "platform-team"
    environment = "dev"
  }
}

run "dead_letter_queue_follows_the_main_queue_name" {
  command = plan

  assert {
    condition     = aws_sqs_queue.dlq.name == "harbor-orders-dlq"
    error_message = "The dead-letter queue must be named <name>-dlq."
  }
}

run "both_queues_are_encrypted" {
  command = plan

  assert {
    condition     = aws_sqs_queue.this.sqs_managed_sse_enabled && aws_sqs_queue.dlq.sqs_managed_sse_enabled
    error_message = "Both queues must use server-side encryption."
  }
}

run "rejects_a_receive_count_above_ten" {
  command = plan

  variables {
    max_receive_count = 11
  }

  expect_failures = [var.max_receive_count]
}

run "rejects_tags_without_an_owner" {
  command = plan

  variables {
    tags = { environment = "dev" }
  }

  expect_failures = [var.tags]
}
