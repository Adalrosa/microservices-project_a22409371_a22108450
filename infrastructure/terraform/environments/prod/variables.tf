variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cloud-ecommerce"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = list(string)            
  default     = ["10.0.2.0/24", "10.0.3.0/24"]  
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "ecommercedb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "public_key" {
  description = "Public SSH key for EC2 access"
  type        = string
}
