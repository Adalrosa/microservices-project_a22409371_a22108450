# Architecture

## Overview

Cloud-native e-commerce backend deployed on AWS using microservices architecture.
Three services communicate via REST (synchronous) and SQS (asynchronous).

## Architecture Diagram

## Services

### catalog-service (port 8081)
- Manages the product catalogue
- REST API: GET /products, POST /products, DELETE /products/{id}
- Connected to PostgreSQL database

### order-service (port 8082)
- Creates and manages orders
- REST API: GET /orders, POST /orders, GET /orders/{id}
- Publishes events to SQS when an order is created
- Connected to PostgreSQL database

### notification-service (port 8083)
- Consumes messages from SQS every 5 seconds
- Logs notifications for each order created
- No direct database connection

## Networking

| Component | Subnet | Reason |
|---|---|---|
| EC2 instances | Public | Need internet access |
| RDS PostgreSQL | Private | No public internet access |
| SQS | AWS Managed | Accessed via IAM |

## VPC Design

- **CIDR** — 10.0.0.0/16
- **Public subnet** — 10.0.1.0/24 (EC2 instances)
- **Private subnet** — 10.0.2.0/24 (RDS database)
- **Internet Gateway** — allows public internet access
- **Security Groups** — web-sg (ports 80, 8081-8083, 22) and db-sg (port 5432)

## Event-Driven Flow

1. Client sends POST /orders to order-service
2. order-service saves order to RDS
3. order-service publishes message to SQS queue
4. notification-service polls SQS every 5 seconds
5. notification-service processes message and deletes it from queue
6. If processing fails 3 times, message goes to Dead Letter Queue (DLQ)

## Terraform Modules

| Module | What it creates |
|---|---|
| vpc | VPC, subnets, IGW, route tables, security groups |
| compute | EC2 instance, IAM role, key pair |
| db | RDS PostgreSQL, subnet group |
| queue | SQS queue, Dead Letter Queue |

## Security

- RDS in private subnet — not accessible from internet
- IAM roles with least privilege
- No hardcoded credentials
- OIDC authentication between GitHub Actions and AWS