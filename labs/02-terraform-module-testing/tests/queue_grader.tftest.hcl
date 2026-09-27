# Grader for lab 02: what the queue module must guarantee. Mocked provider only.
# The two queues get distinct ARNs so the redrive assertions can tell them apart.

mock_provider "aws" {}

override_resource {
  target = aws_sqs_queue.this
  values = {
    arn = "arn:aws:sqs:us-east-1:111122223333:harbor-orders"
    url = "https://sqs.us-east-1.amazonaws.com/111122223333/harbor-orders"
  }
}

override_resource {
  target = aws_sqs_queue.dlq
  values = {
    arn = "arn:aws:sqs:us-east-1:111122223333:harbor-orders-dlq"
    url = "https://sqs.us-east-1.amazonaws.com/111122223333/harbor-orders-dlq"
  }
}

variables {
  name = "harbor-orders"
  tags = {
    owner       = "platform-team"
    environment = "prod"
  }
}

run "rejects_an_invalid_name" {
  command = plan

  variables {
    name = "Harbor_Orders"
  }

  expect_failures = [var.name]
}

run "rejects_a_receive_count_of_zero" {
  command = plan

  variables {
    max_receive_count = 0
  }

  expect_failures = [var.max_receive_count]
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
    tags = { environment = "prod" }
  }

  expect_failures = [var.tags]
}

run "rejects_an_unknown_environment_tag" {
  command = plan

  variables {
    tags = { owner = "platform-team", environment = "qa" }
  }

  expect_failures = [var.tags]
}

run "failed_messages_reach_the_dead_letter_queue" {
  command = apply

  assert {
    condition     = aws_sqs_queue.dlq.name == "harbor-orders-dlq"
    error_message = "The dead-letter queue must be named <name>-dlq."
  }

  assert {
    condition     = jsondecode(aws_sqs_queue.this.redrive_policy).deadLetterTargetArn == "arn:aws:sqs:us-east-1:111122223333:harbor-orders-dlq"
    error_message = "The main queue's redrive policy must target the dead-letter queue."
  }

  assert {
    condition     = jsondecode(aws_sqs_queue.this.redrive_policy).maxReceiveCount == 5
    error_message = "max_receive_count must default to 5 and feed the redrive policy."
  }

  assert {
    condition     = aws_sqs_queue.dlq.message_retention_seconds == 1209600
    error_message = "The dead-letter queue must keep messages for 14 days (1209600 seconds)."
  }

  assert {
    condition     = contains(jsondecode(aws_sqs_queue_redrive_allow_policy.dlq.redrive_allow_policy).sourceQueueArns, "arn:aws:sqs:us-east-1:111122223333:harbor-orders")
    error_message = "Only the main queue may use the dead-letter queue (redrive allow policy byQueue)."
  }
}

run "both_queues_are_encrypted_and_tagged" {
  command = plan

  assert {
    condition     = aws_sqs_queue.this.sqs_managed_sse_enabled && aws_sqs_queue.dlq.sqs_managed_sse_enabled
    error_message = "Both queues must use server-side encryption (sqs_managed_sse_enabled)."
  }

  assert {
    condition     = aws_sqs_queue.this.tags["owner"] == "platform-team" && aws_sqs_queue.dlq.tags["environment"] == "prod"
    error_message = "Both queues must carry the tags passed to the module."
  }
}

run "outputs_expose_both_queues" {
  command = apply

  assert {
    condition     = output.queue_arn == "arn:aws:sqs:us-east-1:111122223333:harbor-orders"
    error_message = "queue_arn must be the main queue's ARN."
  }

  assert {
    condition     = output.dlq_arn == "arn:aws:sqs:us-east-1:111122223333:harbor-orders-dlq"
    error_message = "dlq_arn must be the dead-letter queue's ARN."
  }

  assert {
    condition     = output.queue_url != "" && output.dlq_url != ""
    error_message = "queue_url and dlq_url must be set."
  }
}
