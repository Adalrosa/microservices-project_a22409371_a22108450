# Setup

## Prerequisites

### Local tools required

| Tool | Version | Install |
|---|---|---|
| Java | 17 | https://adoptium.net |
| Maven | 3.9+ | https://maven.apache.org |
| Docker Desktop | latest | https://docker.com |
| Terraform | >= 1.9 | https://terraform.io |
| Ansible | latest | https://ansible.com |
| AWS CLI | v2 | https://aws.amazon.com/cli |
| Git | latest | https://git-scm.com |

### AWS Prerequisites

1. AWS account with credits
2. IAM user with AdministratorAccess
3. AWS CLI configured: `aws configure`

## GitHub Secrets Required

Go to GitHub → Settings → Secrets and add these:

| Secret | Description |
|---|---|
| `AWS_ACCOUNT_ID` | Your AWS account ID (12 digits) |
| `AWS_ROLE_ARN` | ARN of the OIDC role |
| `DB_PASSWORD` | Database password |
| `EC2_PUBLIC_KEY` | SSH public key for EC2 |
| `EC2_PRIVATE_KEY` | SSH private key for EC2 |

## Local Development

```bash
# Clone the repository
git clone https://github.com/Adalrosa/cloud-ecommerce.git
cd cloud-ecommerce

# Run services locally with Docker
docker build -t catalog-service services/catalog-service
docker build -t order-service services/order-service
docker build -t notification-service services/notification-service
```