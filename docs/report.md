# Relatório Final — Cloud E-Commerce

## 1. Introdução

Este projecto implementa um backend de e-commerce nativo na nuvem, implantado na AWS. A aplicação segue uma arquitectura de microserviços e demonstra a aplicação de práticas de engenharia cloud, incluindo Infraestrutura como Código, contentorização, pipelines CI/CD, comunicação orientada a eventos e gestão de configuração.

A aplicação é utilizada como veículo para demonstrar as seguintes tecnologias:
- AWS (EC2, RDS, SQS, ECR, VPC)
- Terraform (Infraestrutura como Código)
- Docker (Contentorização)
- GitHub Actions (CI/CD)
- Ansible (Gestão de Configuração)
- Java + Spring Boot (Aplicação)

---

## 2. Visão Geral da Arquitectura

O sistema é composto por três microserviços que comunicam via REST (síncrono) e SQS (assíncrono).

```
Cliente
  └── EC2 (Subnet Pública) — IP: 18.185.94.172
        ├── catalog-service (porta 8081) ──── RDS PostgreSQL
        └── order-service (porta 8082) ─────── RDS PostgreSQL
              └── SQS: cloud-ecommerce-order-created
                    └── notification-service (porta 8083)
```

### Serviços

| Serviço | Porta | Responsabilidade |
|---|---|---|
| catalog-service | 8081 | Gere o catálogo de produtos |
| order-service | 8082 | Cria ordens e publica eventos no SQS |
| notification-service | 8083 | Consome eventos do SQS e envia notificações |

---

## 3. Infraestrutura Cloud (Requisito 1)

### Design da VPC

| Componente | Valor |
|---|---|
| VPC ID | vpc-09e9a42272747d36c |
| VPC Name | cloud-ecommerce-vpc |
| VPC CIDR | 10.0.0.0/16 |
| Subnet Pública | cloud-ecommerce-public-subnet |
| Subnet Privada | cloud-ecommerce-private-subnet-0 |
| Internet Gateway | cloud-ecommerce-igw |
| Route Table Pública | cloud-ecommerce-public-rt |
| Região | eu-central-1 (Frankfurt) |

### Componentes de Rede
- **Internet Gateway** — `cloud-ecommerce-igw` — permite que as instâncias EC2 na subnet pública acedam à internet
- **Route Tables** — `cloud-ecommerce-public-rt` — encaminha o tráfego público através do Internet Gateway
- **Security Groups** — web-sg (portas 80, 8081-8083, 22) e db-sg (porta 5432 apenas do web-sg)

### Localização dos Recursos

| Recurso | Subnet | Motivo |
|---|---|---|
| EC2 (cloud-ecommerce-app) | cloud-ecommerce-public-subnet | Precisa de acesso à internet para chamadas API |
| RDS PostgreSQL | cloud-ecommerce-private-subnet-0 | Não necessita de acesso público à internet |
| SQS | Gerido pela AWS | Acedido via roles IAM |

---

## 4. Infraestrutura como Código — Terraform (Requisito 2)

Toda a infraestrutura é provisionada usando Terraform, organizada em módulos reutilizáveis.

### Estrutura dos Módulos

```
infrastructure/terraform/
├── modules/
│   ├── vpc/         # VPC, subnets, security groups, IGW, route tables
│   ├── compute/     # Instância EC2, role IAM, key pair
│   ├── db/          # RDS PostgreSQL, subnet group
│   └── queue/       # Fila SQS, Dead Letter Queue
└── environments/
    └── prod/        # main.tf, variables.tf, outputs.tf, terraform.tfvars
```

### Estado Remoto

O estado do Terraform é armazenado remotamente no AWS S3 com bloqueio DynamoDB:
- **S3 Bucket**: `cloud-ecommerce-terraform-state`
- **Tabela DynamoDB**: `cloud-ecommerce-terraform-locks`
- **Encriptação**: activada
- **Região**: eu-central-1

### Como Executar o Terraform

```bash
# Passo 1 — Configurar credenciais AWS
aws configure
# AWS Access Key ID: A_TUA_CHAVE
# AWS Secret Access Key: O_TEU_SEGREDO
# Default region: eu-central-1

# Passo 2 — Criar o backend (executar apenas uma vez)
aws s3api create-bucket \
  --bucket cloud-ecommerce-terraform-state \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-bucket-versioning \
  --bucket cloud-ecommerce-terraform-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name cloud-ecommerce-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1

# Passo 3 — Navegar para o ambiente
cd infrastructure/terraform/environments/prod

# Passo 4 — Inicializar o Terraform
terraform init

# Passo 5 — Ver as alterações antes de aplicar
terraform plan \
  -var="db_password=ChangeMe123!" \
  -var="public_key=$(cat ~/.ssh/cloud-ecommerce-key.pub)"

# Passo 6 — Aplicar a infraestrutura
terraform apply \
  -var="db_password=ChangeMe123!" \
  -var="public_key=$(cat ~/.ssh/cloud-ecommerce-key.pub)"

# Passo 7 — Ver os outputs
terraform output ec2_public_ip
terraform output db_endpoint
terraform output sqs_queue_url

# Passo 8 — Destruir a infraestrutura (após o projecto)
terraform destroy
```

---

## 5. Contentorização (Requisito 3)

Cada serviço tem um Dockerfile multi-stage que:
1. Compila a aplicação Java usando Maven
2. Cria uma imagem de runtime mínima usando Alpine JRE

### Exemplo de Dockerfile (catalog-service)

```dockerfile
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Registo de Contentores — AWS ECR

**Account ID**: `930124786319`
**Região**: `eu-central-1`

| Serviço | Repositório ECR |
|---|---|
| catalog-service | `930124786319.dkr.ecr.eu-central-1.amazonaws.com/catalog-service` |
| order-service | `930124786319.dkr.ecr.eu-central-1.amazonaws.com/order-service` |
| notification-service | `930124786319.dkr.ecr.eu-central-1.amazonaws.com/notification-service` |

### Como Compilar e Fazer Push das Imagens

```bash
# Passo 1 — Autenticar no ECR
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin \
  930124786319.dkr.ecr.eu-central-1.amazonaws.com

# Passo 2 — Compilar e fazer push do catalog-service
docker build -t 930124786319.dkr.ecr.eu-central-1.amazonaws.com/catalog-service:latest \
  services/catalog-service
docker push 930124786319.dkr.ecr.eu-central-1.amazonaws.com/catalog-service:latest

# Passo 3 — Compilar e fazer push do order-service
docker build -t 930124786319.dkr.ecr.eu-central-1.amazonaws.com/order-service:latest \
  services/order-service
docker push 930124786319.dkr.ecr.eu-central-1.amazonaws.com/order-service:latest

# Passo 4 — Compilar e fazer push do notification-service
docker build -t 930124786319.dkr.ecr.eu-central-1.amazonaws.com/notification-service:latest \
  services/notification-service
docker push 930124786319.dkr.ecr.eu-central-1.amazonaws.com/notification-service:latest
```

---

## 6. Arquitectura Distribuída (Requisito 4)

O sistema segue uma arquitectura de microserviços com três serviços independentes:

### catalog-service (porta 8081)
- **API REST**:
    - `GET /products` — listar todos os produtos
    - `GET /products/{id}` — obter produto por ID
    - `POST /products` — criar um produto
    - `DELETE /products/{id}` — eliminar um produto

### order-service (porta 8082)
- **API REST**:
    - `GET /orders` — listar todas as ordens
    - `GET /orders/{id}` — obter ordem por ID
    - `POST /orders` — criar uma ordem (também publica no SQS)

### notification-service (porta 8083)
- Sem API REST
- Verifica o SQS a cada 5 segundos
- Processa e confirma mensagens

### Como Testar os Serviços

```bash
# Listar produtos
curl http://18.185.94.172:8081/products

# Criar um produto
curl -X POST http://18.185.94.172:8081/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Produto A", "description": "Descrição", "price": 29.99}'

# Criar uma ordem (publica automaticamente no SQS)
curl -X POST http://18.185.94.172:8082/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 1, "quantity": 2}'

# Listar ordens
curl http://18.185.94.172:8082/orders
```

---

## 7. Comunicação Orientada a Eventos (Requisito 5)

### Filas SQS Criadas

| Fila | ARN | URL |
|---|---|---|
| order-created | `arn:aws:sqs:eu-central-1:930124786319:cloud-ecommerce-order-created` | `https://sqs.eu-central-1.amazonaws.com/930124786319/cloud-ecommerce-order-created` |
| order-created-dlq | `arn:aws:sqs:eu-central-1:930124786319:cloud-ecommerce-order-created-dlq` | `https://sqs.eu-central-1.amazonaws.com/930124786319/cloud-ecommerce-order-created-dlq` |

### Fluxo de Mensagens

```
1. Cliente → POST /orders → order-service (porta 8082)
2. order-service → guarda ordem no RDS PostgreSQL
3. order-service → publica mensagem no SQS: cloud-ecommerce-order-created
4. notification-service → verifica SQS a cada 5 segundos
5. notification-service → processa mensagem e regista notificação
6. notification-service → elimina mensagem do SQS
7. Se o processamento falhar 3 vezes → mensagem vai para a DLQ
```

### Formato da Mensagem SQS

```json
{
  "orderId": 1,
  "productId": 2,
  "quantity": 3,
  "status": "PENDING"
}
```

---

## 8. Camada de Persistência (Requisito 6)

### RDS PostgreSQL

| Parâmetro | Valor |
|---|---|
| Identificador | cloud-ecommerce-db |
| Endpoint | cloud-ecommerce-db.cj4qw082yvgs.eu-central-1.rds.amazonaws.com |
| Motor | PostgreSQL 15 |
| Classe | db.t3.micro |
| Armazenamento | 20 GB |
| Subnet | cloud-ecommerce-private-subnet-0 |
| Acesso público | Não |
| Zona | eu-central-1a |

### Bases de Dados

| Serviço | Base de Dados |
|---|---|
| catalog-service | catalogdb |
| order-service | orderdb |

### Como Ligar à Base de Dados

```bash
# Ligar via psql (apenas dentro da VPC)
psql -h cloud-ecommerce-db.cj4qw082yvgs.eu-central-1.rds.amazonaws.com \
  -U dbadmin \
  -d ecommercedb \
  -p 5432
```

---

## 9. Gestão de Configuração — Ansible (Requisito 7)

O Ansible é usado para configurar instâncias EC2 e implementar contentores Docker.

### Como Executar o Ansible

```bash
# Passo 1 — Instalar Ansible
pip install ansible

# Passo 2 — Actualizar o inventário
# Editar ansible/inventory/hosts.ini com os valores reais:
# EC2 IP: 18.185.94.172
# RDS Endpoint: cloud-ecommerce-db.cj4qw082yvgs.eu-central-1.rds.amazonaws.com
# SQS URL: https://sqs.eu-central-1.amazonaws.com/930124786319/cloud-ecommerce-order-created

# Passo 3 — Executar o playbook
ansible-playbook ansible/playbooks/deploy.yml \
  -i ansible/inventory/hosts.ini \
  --private-key ~/.ssh/cloud-ecommerce-key.pem
```

### O que o Ansible Faz

1. Actualiza os pacotes do sistema
2. Instala o Docker
3. Inicia e activa o serviço Docker
4. Adiciona ec2-user ao grupo docker
5. Instala o AWS CLI
6. Autentica no ECR (`930124786319.dkr.ecr.eu-central-1.amazonaws.com`)
7. Descarrega e executa os três contentores Docker

---

## 10. Pipeline CI/CD — GitHub Actions (Requisito 8)

### Workflows

| Workflow | Gatilho | Acções |
|---|---|---|
| `ci.yml` | Pull Request para main | Compilar Java, validar Terraform, compilar imagens Docker |
| `deploy.yml` | Push para main | Compilar + enviar para ECR, terraform apply, deploy Ansible |

### Resultado do Teste OIDC

O teste de autenticação OIDC foi executado com sucesso:
- **Status**: ✅ Success
- **Duração**: 11 segundos
- **Role assumido**: `arn:aws:sts::930124786319:assumed-role/gha-deployer/GitHubActions`
- **Account**: `930124786319`

### Autenticação OIDC

O GitHub Actions autentica na AWS usando OIDC sem credenciais estáticas:

```yaml
- name: Configurar credenciais AWS via OIDC
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    aws-region: eu-central-1
```

### GitHub Secrets Configurados

| Secret | Estado |
|---|---|
| `AWS_ROLE_TO_ASSUME` | ✅ Configurado |

---

## 11. Segurança e IAM (Requisito 9)

### Identity Provider OIDC

| Campo | Valor |
|---|---|
| Provider | token.actions.githubusercontent.com |
| Provider Type | OpenID Connect |
| ARN | `arn:aws:iam::930124786319:oidc-provider/token.actions.githubusercontent.com` |
| Audience | sts.amazonaws.com |
| Data de Criação | June 07, 2026 |

### Role IAM — EC2 (cloud-ecommerce-ec2-role)

Permissões com princípio do menor privilégio:

```json
{
  "Acções": [
    "sqs:SendMessage",
    "sqs:ReceiveMessage",
    "sqs:DeleteMessage",
    "sqs:GetQueueAttributes",
    "ecr:GetAuthorizationToken",
    "ecr:BatchGetImage",
    "ecr:GetDownloadUrlForLayer"
  ]
}
```

### Role IAM — GitHub Actions (gha-deployer)
- Sem credenciais de longa duração
- Autenticado via token OIDC
- Permissões limitadas apenas a acções de deployment

### Medidas de Segurança

- RDS em subnet privada — não acessível da internet
- `terraform.tfvars` no `.gitignore` — sem segredos no git
- Todos os segredos via GitHub Secrets ou variáveis de ambiente
- Security groups bem definidos (db-sg só permite porta 5432 do web-sg)
- OIDC em vez de chaves de acesso AWS estáticas

---

## 12. Como Fazer Deploy em Qualquer Máquina

Execute estes comandos por ordem em qualquer máquina:

```bash
# 1. Instalar ferramentas necessárias
# - AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# - Terraform >= 1.9: https://terraform.io
# - Docker Desktop: https://docker.com
# - Ansible: pip install ansible
# - Java 17: https://adoptium.net

# 2. Clonar o repositório
git clone https://github.com/Adalrosa/cloud-ecommerce.git
cd cloud-ecommerce

# 3. Configurar o AWS CLI
aws configure
# AWS Access Key ID: A_TUA_CHAVE
# AWS Secret Access Key: O_TEU_SEGREDO
# Default region: eu-central-1

# 4. Criar o backend do Terraform (executar apenas uma vez)
aws s3api create-bucket \
  --bucket cloud-ecommerce-terraform-state \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-bucket-versioning \
  --bucket cloud-ecommerce-terraform-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name cloud-ecommerce-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1

# 5. Gerar par de chaves SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cloud-ecommerce-key

# 6. Fazer deploy da infraestrutura
cd infrastructure/terraform/environments/prod
terraform init
terraform apply \
  -var="db_password=ChangeMe123!" \
  -var="public_key=$(cat ~/.ssh/cloud-ecommerce-key.pub)"

# 7. Ver os outputs do Terraform
terraform output ec2_public_ip
# Resultado: 18.185.94.172

terraform output db_endpoint
# Resultado: cloud-ecommerce-db.cj4qw082yvgs.eu-central-1.rds.amazonaws.com

terraform output sqs_queue_url
# Resultado: https://sqs.eu-central-1.amazonaws.com/930124786319/cloud-ecommerce-order-created

# 8. Autenticar no ECR e fazer push das imagens
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin \
  930124786319.dkr.ecr.eu-central-1.amazonaws.com

docker build -t 930124786319.dkr.ecr.eu-central-1.amazonaws.com/catalog-service:latest services/catalog-service
docker push 930124786319.dkr.ecr.eu-central-1.amazonaws.com/catalog-service:latest

docker build -t 930124786319.dkr.ecr.eu-central-1.amazonaws.com/order-service:latest services/order-service
docker push 930124786319.dkr.ecr.eu-central-1.amazonaws.com/order-service:latest

docker build -t 930124786319.dkr.ecr.eu-central-1.amazonaws.com/notification-service:latest services/notification-service
docker push 930124786319.dkr.ecr.eu-central-1.amazonaws.com/notification-service:latest

# 9. Actualizar o inventário Ansible
# Editar ansible/inventory/hosts.ini:
# [app_servers]
# 18.185.94.172 ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/cloud-ecommerce-key.pem
#
# [app_servers:vars]
# ecr_registry=930124786319.dkr.ecr.eu-central-1.amazonaws.com
# db_host=cloud-ecommerce-db.cj4qw082yvgs.eu-central-1.rds.amazonaws.com
# db_user=dbadmin
# db_password=ChangeMe123!
# sqs_queue_url=https://sqs.eu-central-1.amazonaws.com/930124786319/cloud-ecommerce-order-created

# 10. Executar o Ansible
cd ../../../..
ansible-playbook ansible/playbooks/deploy.yml \
  -i ansible/inventory/hosts.ini \
  --private-key ~/.ssh/cloud-ecommerce-key.pem

# 11. Testar o deployment
curl http://18.185.94.172:8081/products
curl http://18.185.94.172:8082/orders
curl -X POST http://18.185.94.172:8082/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 1, "quantity": 2}'

# 12. Destruir a infraestrutura após o projecto
cd infrastructure/terraform/environments/prod
terraform destroy
```

---

## 13. Estrutura do Repositório

```
cloud-ecommerce/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── setup.md
│   ├── deployment.md
│   ├── security.md
│   └── limitations.md
├── services/
│   ├── catalog-service/
│   │   ├── Dockerfile
│   │   └── src/
│   ├── order-service/
│   │   ├── Dockerfile
│   │   └── src/
│   └── notification-service/
│       ├── Dockerfile
│       └── src/
├── infrastructure/
│   └── terraform/
│       ├── modules/
│       │   ├── vpc/
│       │   ├── compute/
│       │   ├── db/
│       │   └── queue/
│       └── environments/
│           └── prod/
├── ansible/
│   ├── playbooks/
│   │   └── deploy.yml
│   └── inventory/
│       └── hosts.ini
└── .github/
    └── workflows/
        ├── ci.yml
        └── deploy.yml
```

---

## 14. Recursos AWS Criados

| Recurso | Nome | ID/Endpoint |
|---|---|---|
| VPC | cloud-ecommerce-vpc | vpc-09e9a42272747d36c |
| Subnet Pública | cloud-ecommerce-public-subnet | eu-central-1a |
| Subnet Privada | cloud-ecommerce-private-subnet-0 | eu-central-1a |
| Internet Gateway | cloud-ecommerce-igw | — |
| EC2 | cloud-ecommerce-app | 18.185.94.172 |
| RDS | cloud-ecommerce-db | cloud-ecommerce-db.cj4qw082yvgs.eu-central-1.rds.amazonaws.com |
| SQS | cloud-ecommerce-order-created | https://sqs.eu-central-1.amazonaws.com/930124786319/cloud-ecommerce-order-created |
| SQS DLQ | cloud-ecommerce-order-created-dlq | https://sqs.eu-central-1.amazonaws.com/930124786319/cloud-ecommerce-order-created-dlq |
| ECR | catalog-service | 930124786319.dkr.ecr.eu-central-1.amazonaws.com/catalog-service |
| ECR | order-service | 930124786319.dkr.ecr.eu-central-1.amazonaws.com/order-service |
| ECR | notification-service | 930124786319.dkr.ecr.eu-central-1.amazonaws.com/notification-service |
| IAM Role EC2 | cloud-ecommerce-ec2-role | — |
| IAM Role GHA | gha-deployer | arn:aws:sts::930124786319:assumed-role/gha-deployer |
| OIDC Provider | token.actions.githubusercontent.com | arn:aws:iam::930124786319:oidc-provider/... |

---

## 15. Limitações e Melhorias Futuras

### Limitações Actuais
- Instância EC2 única — sem alta disponibilidade
- Zona de disponibilidade única (eu-central-1a)
- Sem auto-scaling configurado
- Sem ALB (Application Load Balancer)
- Sem monitorização CloudWatch

### Melhorias Futuras
- Migrar para ECS/Fargate para melhor gestão de contentores
- Adicionar ALB para balanceamento de carga
- Configurar logs e alarmes CloudWatch
- RDS Multi-AZ para alta disponibilidade
- Auto-scaling baseado na profundidade da fila SQS
- Estratégia de deployment Blue/Green