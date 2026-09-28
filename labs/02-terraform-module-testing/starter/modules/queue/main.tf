# An SQS queue for Harbor Goods order events.
#
# Exercise 4: add a dead-letter queue, aws_sqs_queue.dlq, named "<name>-dlq",
# keeping messages for 14 days (1209600 seconds).
# Exercise 5: point the main queue's redrive_policy at the dead-letter queue with
# jsonencode({ deadLetterTargetArn = ..., maxReceiveCount = var.max_receive_count }).
# Exercise 6: turn on sqs_managed_sse_enabled on both queues and tag both.
# Exercise 7: add aws_sqs_queue_redrive_allow_policy.dlq so that only the main queue
# may send messages to the dead-letter queue (redrivePermission "byQueue").

resource "aws_sqs_queue" "this" {
  name                       = var.name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  tags                       = var.tags
}
