output "queue_url" {
  description = "URL of the orders queue."
  value       = module.orders.queue_url
}

output "dlq_arn" {
  description = "ARN of the orders dead-letter queue."
  value       = module.orders.dlq_arn
}
