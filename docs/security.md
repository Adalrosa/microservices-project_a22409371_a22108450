# Security

## IAM Roles

### GitHub Actions OIDC Role
- Allows GitHub Actions to authenticate to AWS without static credentials
- Permissions: ECR push, Terraform apply, SQS access
- No long-lived access keys

### EC2 Instance Role
- Attached to all EC2 instances
- Permissions:
    - `sqs:SendMessage` — order-service publishes to SQS
    - `sqs:ReceiveMessage` — notification-service consumes from SQS
    - `sqs:DeleteMessage` — notification-service deletes processed messages
    - `ecr:GetAuthorizationToken` — pull images from ECR
    - `ecr:BatchGetImage` — pull images from ECR

## Network Security

### Public Subnet
- EC2 instances — accessible on ports 8081, 8082, 8083
- Port 22 (SSH) — for Ansible configuration

### Private Subnet
- RDS PostgreSQL — only accessible from web security group
- Not accessible from the public internet

### Security Groups
- `web-sg` — allows HTTP traffic on ports 8081-8083
- `db-sg` — only allows PostgreSQL (5432) from web-sg

## Secrets Management

| Secret | Where stored |
|---|---|
| DB password | GitHub Secrets + terraform.tfvars (not committed) |
| SSH private key | GitHub Secrets |
| AWS credentials | OIDC (no static keys) |

## No Hardcoded Credentials

- `terraform.tfvars` is in `.gitignore`
- No passwords in source code
- All secrets via environment variables
- OIDC used instead of AWS access keys

## Least Privilege Principle

- EC2 role only has SQS and ECR permissions
- GitHub Actions role only has deployment permissions
- RDS only accessible from application security group