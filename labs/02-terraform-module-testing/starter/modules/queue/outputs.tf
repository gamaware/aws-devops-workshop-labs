output "queue_url" {
  description = "URL of the main queue, used by producers and consumers."
  value       = aws_sqs_queue.this.url
}

output "queue_arn" {
  description = "ARN of the main queue, used in IAM policies and event source mappings."
  value       = aws_sqs_queue.this.arn
}

# Exercise 8: add dlq_url and dlq_arn outputs.
