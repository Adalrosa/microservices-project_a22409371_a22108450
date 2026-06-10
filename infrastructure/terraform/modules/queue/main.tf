resource "aws_sqs_queue" "order_created_dlq" {
  name                      = "${var.project_name}-order-created-dlq"
  message_retention_seconds = 1209600

  tags = {
    Name        = "${var.project_name}-order-created-dlq"
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "order_created" {
  name                      = "${var.project_name}-order-created"
  message_retention_seconds = 86400
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_created_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${var.project_name}-order-created"
    Environment = var.environment
  }
}
