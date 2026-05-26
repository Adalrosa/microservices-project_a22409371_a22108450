# Week 10 – SQS (`product-events`)

This folder contains **Terraform** for the Amazon SQS resources used by the course microservices.

The **Java/Spring code** (producer in `product-service`, consumer in `order-service`) already lives in the template repository. For Week 10, students focus on **cloud infrastructure**: queues, dead-letter queue, redrive policy, IAM, and wiring **environment variables** so the apps can reach AWS.

## What gets created

- Standard queue: `{name_prefix}-product-events` (default prefix `cn-course`)
- Dead-letter queue: `{name_prefix}-product-events-dlq`
- Redrive policy on the main queue (`max_receive_count` configurable)

## Prerequisites

- Terraform 1.x
- AWS credentials configured (`aws configure` or environment / role)
- Permissions to create SQS queues and policies in the target account

## Usage

```bash
cd infra/week9-sqs
terraform init
terraform plan
terraform apply
```

After apply, note the **queue URL** output. Both services use the **same URL** (producer and consumer).

## Connect the microservices

Set (examples; Spring Boot maps `CLOUD_SQS_*` to `cloud.sqs.*`):

```bash
export AWS_REGION=eu-west-1
export CLOUD_SQS_PRODUCT_EVENTS_ENABLED=true
export CLOUD_SQS_PRODUCT_EVENTS_QUEUE_URL="https://sqs....amazonaws.com/.../cn-course-product-events"
export CLOUD_SQS_PRODUCT_EVENTS_CONSUMER_ENABLED=true
export CLOUD_SQS_PRODUCT_EVENTS_CONSUMER_QUEUE_URL="$CLOUD_SQS_PRODUCT_EVENTS_QUEUE_URL"
```

Spring maps these to:

- `cloud.sqs.product-events.*` (product-service producer)
- `cloud.sqs.product-events-consumer.*` (order-service long poll)

Alternatively, you can keep `enabled: false` in `application.yml` and override only via your shell / ECS task definition / EC2 user-data as above.

## Destroy

```bash
terraform destroy
```

**Warning:** Destroying removes queues and any undrained messages.
