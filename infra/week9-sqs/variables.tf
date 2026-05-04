variable "name_prefix" {
  type        = string
  description = "Prefix for queue names (letters, numbers, hyphens)."
  default     = "cn-course"
}

variable "max_receive_count_before_dlq" {
  type        = number
  description = "Number of receives before a message is moved to the DLQ."
  default     = 5
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to both queues."
  default = {
    Course = "cloud-computing"
    Week   = "10"
  }
}
