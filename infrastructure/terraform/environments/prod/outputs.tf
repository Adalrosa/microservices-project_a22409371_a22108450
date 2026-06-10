output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.compute.public_ip
}

output "db_endpoint" {
  description = "Endpoint of the RDS database"
  value       = module.db.db_endpoint
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = module.queue.queue_url
}