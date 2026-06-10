# Deployment

## Step 1 — Configure AWS credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter region: eu-central-1
```

## Step 2 — Create Terraform backend

In the AWS console:

1. Create S3 bucket: `cloud-ecommerce-terraform-state`
2. Enable versioning on the bucket
3. Create DynamoDB table: `cloud-ecommerce-terraform-locks`
    - Primary key: `LockID` (String)

## Step 3 — Deploy infrastructure

```bash
cd infrastructure/terraform/environments/prod
terraform init
terraform plan
terraform apply
```

## Step 4 — Configure EC2 with Ansible

Update `ansible/inventory/hosts.ini` with the EC2 public IP and RDS endpoint from the Terraform outputs.

```bash
ansible-playbook ansible/playbooks/deploy.yml -i ansible/inventory/hosts.ini
```

## Step 5 — Verify deployment

```bash
# Check catalog-service
curl http://<EC2_PUBLIC_IP>:8081/products

# Check order-service
curl http://<EC2_PUBLIC_IP>:8082/orders

# Create a test order
curl -X POST http://<EC2_PUBLIC_IP>:8082/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 1, "quantity": 2}'
```

## CI/CD Pipeline

Every push to `main` branch automatically:

1. Builds Java services
2. Builds and pushes Docker images to ECR
3. Runs `terraform apply`
4. Runs Ansible playbook to deploy

## Tear Down

```bash
cd infrastructure/terraform/environments/prod
terraform destroy
```

⚠️ Always run `terraform destroy` after the project to avoid costs!