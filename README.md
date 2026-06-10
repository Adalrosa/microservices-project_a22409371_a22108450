# cloud-ecommerce

Cloud-native e-commerce backend deployed on AWS using Terraform, Docker, GitHub Actions, and Ansible.

## Architecture

Three microservices communicating via REST and SQS:

- **catalog-service** — manages products
- **order-service** — creates orders and publishes events to SQS
- **notification-service** — consumes SQS events and sends notifications

## Tech Stack

| Layer | Technology |
|---|---|
| Cloud | AWS (EC2, RDS, SQS, ECR, VPC) |
| IaC | Terraform |
| Containers | Docker |
| CI/CD | GitHub Actions |
| Config Mgmt | Ansible |
| Language | Java + Spring Boot |
| Database | PostgreSQL (RDS) |

## How to Deploy

1. Configure AWS credentials
2. Run `terraform apply` in `infrastructure/terraform/environments/prod`
3. Run Ansible playbook: `ansible-playbook ansible/playbooks/deploy.yml`

## Repository Structure
```
cloud-ecommerce/
├── services/          # Java Spring Boot microservices
├── infrastructure/    # Terraform modules and environments
├── ansible/           # Configuration management
├── docs/              # Architecture and deployment docs
└── .github/workflows/ # CI/CD pipelines
```

## Documentation

- [Architecture](docs/architecture.md)
- [Setup](docs/setup.md)
- [Deployment](docs/deployment.md)
- [Security](docs/security.md)

- ## Services

| Service | Port | Description |
|---|---|---|
| catalog-service | 8081 | Manages products |
| order-service | 8082 | Creates orders and publishes to SQS |
| notification-service | 8083 | Consumes SQS events |

## Infrastructure

- **VPC** — Custom VPC with public and private subnets
- **EC2** — Application servers in public subnet
- **RDS** — PostgreSQL database in private subnet
- **SQS** — Message queue with Dead Letter Queue
- **ECR** — Container registry for Docker images

## Prerequisites

- AWS CLI configured
- Terraform >= 1.9
- Docker Desktop
- Java 17
- Ansible

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/Adalrosa/cloud-ecommerce.git
cd cloud-ecommerce

# 2. Deploy infrastructure
cd infrastructure/terraform/environments/prod
terraform init
terraform apply

# 3. Configure EC2 with Ansible
ansible-playbook ansible/playbooks/deploy.yml

# 4. Access services
curl http://<EC2_PUBLIC_IP>:8081/products
curl http://<EC2_PUBLIC_IP>:8082/orders
```
