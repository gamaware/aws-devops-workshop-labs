variable "name" {
  description = "Queue name. The dead-letter queue is named <name>-dlq."
  type        = string

  # Exercise 1: validate the name: 1 to 76 lowercase letters, digits or hyphens,
  # starting with a letter or digit, so that "<name>-dlq" still fits the 80-character limit.
}

variable "visibility_timeout_seconds" {
  description = "How long a received message stays hidden from other consumers. Set it above the consumer's processing time."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags for both queues. Harbor Goods requires owner and environment (dev, staging or prod)."
  type        = map(string)

  # Exercise 2: enforce the tagging standard with two validation blocks:
  #   - the map contains the keys owner and environment
  #   - environment is dev, staging or prod
}

# Exercise 3: add a number variable "max_receive_count" (default 5) that accepts
# whole numbers from 1 to 10.
