output "queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.order_created.url
}

output "queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.order_created.arn
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.order_created_dlq.url
}