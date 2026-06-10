provider "aws" {
  region = var.aws_region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "cloud-ecommerce-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "cloud-ecommerce-terraform-locks"
    encrypt        = true
  }
}

module "vpc" {
  source              = "../../modules/vpc"
  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "queue" {
  source       = "../../modules/queue"
  project_name = var.project_name
  environment  = var.environment
}

module "db" {
  source               = "../../modules/db"
  project_name         = var.project_name
  environment          = var.environment
  subnet_ids           = module.vpc.private_subnet_ids
  db_security_group_id = module.vpc.db_security_group_id
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
}

module "compute" {
  source            = "../../modules/compute"
  project_name      = var.project_name
  environment       = var.environment
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.vpc.web_security_group_id
  public_key        = var.public_key
  sqs_queue_arn     = module.queue.queue_arn
}
