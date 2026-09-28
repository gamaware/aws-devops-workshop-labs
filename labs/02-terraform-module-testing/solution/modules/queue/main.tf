# An SQS queue with a dead-letter queue: the smallest reusable unit Harbor Goods
# needs for order events. Messages that fail max_receive_count times move to the
# dead-letter queue instead of blocking the main queue.

# SSE-SQS (sqs_managed_sse_enabled) is free; a real engagement may pass a customer managed key.
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = 1209600 # 14 days, the maximum: time to investigate and redrive
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

resource "aws_sqs_queue" "this" {
  name                       = var.name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  sqs_managed_sse_enabled    = true
  tags                       = var.tags

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

# Only this module's main queue may send failed messages to the dead-letter queue.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}
