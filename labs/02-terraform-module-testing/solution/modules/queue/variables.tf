variable "name" {
  description = "Queue name. The dead-letter queue is named <name>-dlq."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,75}$", var.name))
    error_message = "Use 1 to 76 lowercase letters, digits or hyphens, starting with a letter or digit (the -dlq suffix must still fit in 80)."
  }
}

variable "max_receive_count" {
  description = "Receives before a message moves to the dead-letter queue."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 10 && floor(var.max_receive_count) == var.max_receive_count
    error_message = "max_receive_count must be a whole number from 1 to 10."
  }
}

variable "visibility_timeout_seconds" {
  description = "How long a received message stays hidden from other consumers. Set it above the consumer's processing time."
  type        = number
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 0 and 43200 (12 hours)."
  }
}

variable "tags" {
  description = "Tags for both queues. Harbor Goods requires owner and environment (dev, staging or prod)."
  type        = map(string)

  validation {
    condition     = contains(keys(var.tags), "owner") && contains(keys(var.tags), "environment")
    error_message = "tags must include owner and environment."
  }

  validation {
    condition     = contains(["dev", "staging", "prod"], lookup(var.tags, "environment", ""))
    error_message = "tags.environment must be dev, staging or prod."
  }
}
