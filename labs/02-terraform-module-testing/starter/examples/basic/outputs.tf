output "queue_url" {
  description = "URL of the orders queue."
  value       = module.orders.queue_url
}
