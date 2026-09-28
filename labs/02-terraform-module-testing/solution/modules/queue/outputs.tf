output "queue_url" {
  description = "URL of the main queue, used by producers and consumers."
  value       = aws_sqs_queue.this.url
}

output "queue_arn" {
  description = "ARN of the main queue, used in IAM policies and event source mappings."
  value       = aws_sqs_queue.this.arn
}

output "dlq_url" {
  description = "URL of the dead-letter queue."
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue, used for alarms and redrive."
  value       = aws_sqs_queue.dlq.arn
}
