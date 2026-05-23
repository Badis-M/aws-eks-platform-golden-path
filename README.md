# AWS EKS Platform Golden Path

A production-inspired DevOps / SRE / Platform Engineering lab that demonstrates how to provision, deploy, validate, and destroy an ephemeral Kubernetes platform on AWS.

The project is designed to stay cost-aware while still covering real platform engineering concerns: Terraform modules, remote Terraform state, EKS, ECR, Helm, Docker, IAM, Kubernetes access management, application health checks, GitHub Actions OIDC, and reproducible workflows.

## Project pitch

This repository provides a reusable "golden path" for deploying a small FastAPI service to Amazon EKS.

The goal is not to run EKS for the sake of running EKS. The goal is to demonstrate a complete platform workflow:

```text
Application code
→ Docker image
→ ECR registry
→ Helm deployment
→ EKS runtime
→ Health validation
→ Terraform destroy
```

The platform is intentionally ephemeral: infrastructure is created for testing and demonstration, then destroyed to control AWS costs.

## Architecture

```text
Developer laptop
  |
  | Terraform
  v
S3 remote backend
  |
  | Terraform provisions
  v
AWS ECR + Amazon EKS
  |
  | Helm deployment
  v
FastAPI Incident API
```

Terraform state is stored remotely:

```text
S3 bucket
→ stores terraform.tfstate

S3 native lockfile
→ protects against concurrent state writes
```

Terraform provisions:

```text
VPC
Public subnets
Internet Gateway
EKS cluster
Managed node group
ECR repository
IAM roles
EKS access entries
GitHub OIDC provider
GitHub Actions ECR push role
```

## Technology stack

| Area | Tools |
|---|---|
| Cloud | AWS |
| Kubernetes | Amazon EKS |
| Infrastructure as Code | Terraform |
| Terraform state | S3 remote backend with native lockfile |
| Container registry | Amazon ECR |
| Application packaging | Docker |
| Kubernetes deployment | Helm |
| API | Python FastAPI |
| Testing | Pytest |
| Access management | IAM, EKS Access Entries, GitHub OIDC |
| CI/CD | GitHub Actions |
| Cost control | Ephemeral infrastructure, Terraform destroy, no NAT Gateway in V1 |

## Current V1 status

Implemented and validated:

- FastAPI application with `/health`, `/ready`, and incident endpoints
- Local Python tests
- Dockerfile using non-root runtime user
- Helm chart with probes and resource limits
- Terraform modules for network, EKS, ECR, and IAM/OIDC
- Separate Terraform bootstrap stack for the remote backend
- S3 remote Terraform backend with versioning, encryption, public access block, and native lockfile
- EKS cluster deployed successfully
- ECR image push validated locally
- API deployed on EKS through Helm
- `/health` and `/ready` validated through port-forward
- Full infrastructure destroy validated
- GitHub Actions CI for Python, Docker, Helm, and Terraform validation
- GitHub OIDC smoke test validated with AWS STS
- GitHub Actions ECR image push validated through OIDC without static AWS keys

## Continuous Integration

The repository includes GitHub Actions workflows to validate the main project layers on every push and pull request.

| Workflow | Purpose |
|---|---|
| Python CI | Installs the FastAPI dependencies and runs the pytest test suite |
| Docker CI | Builds the Incident API Docker image to validate container packaging |
| Platform CI | Validates Helm and Terraform configuration |
| OIDC Smoke Test | Manually validates that GitHub Actions can assume an AWS IAM role through OIDC |
| ECR Push | Manually builds and pushes the Incident API image to Amazon ECR through OIDC |

Automatic CI checks:

```text
Python CI
→ checkout
→ setup Python
→ install dependencies
→ run pytest

Docker CI
→ checkout
→ docker build

Platform CI
→ Helm lint
→ Helm template
→ Terraform fmt check
→ Terraform init without backend
→ Terraform validate
```

Manual AWS workflows:

```text
OIDC Smoke Test
→ checkout
→ request GitHub OIDC token
→ assume AWS IAM role
→ aws sts get-caller-identity

ECR Push
→ checkout
→ assume AWS IAM role through OIDC
→ login to Amazon ECR
→ setup Docker Buildx
→ build linux/amd64 image
→ push version and commit-SHA tags to ECR
```

The current CI does not automatically deploy to EKS. AWS deployment automation will be added later through controlled workflows and least-privilege IAM roles.

## Terraform remote backend

The project uses a separate bootstrap stack to create the Terraform backend resources:

```text
terraform/bootstrap/backend
```

This stack creates the S3 bucket used by the main environment backend.

The main environment then uses:

```text
terraform/environments/dev
```

with an S3 backend.

Remote backend responsibilities:

```text
S3 bucket
→ stores the Terraform state remotely

S3 native lockfile
→ prevents concurrent state writes

Bucket versioning
→ keeps previous state versions

Server-side encryption
→ encrypts state at rest

Public access block
→ prevents accidental public exposure
```

The backend uses:

```hcl
use_lockfile = true
```

DynamoDB locking is intentionally not used because the older `dynamodb_table` backend parameter is deprecated.

## GitHub OIDC to AWS

This project uses GitHub Actions OIDC to let selected workflows assume an AWS IAM role without storing long-lived AWS access keys in GitHub Secrets.

The current OIDC flow is:

```text
GitHub Actions workflow
→ temporary OIDC token
→ AWS IAM OIDC provider
→ IAM role assumption
→ temporary AWS credentials
→ ECR push
```

Security properties:

```text
No AWS access keys stored in GitHub
Temporary credentials only
IAM trust scoped to this repository and main branch
ECR permissions scoped to the incident-api repository
No EKS or Terraform apply permissions in the ECR push role
```

## Repository structure

```text
.
├── apps/
│   └── incident-api/
├── helm/
│   └── incident-api/
├── terraform/
│   ├── bootstrap/
│   │   └── backend/
│   ├── environments/
│   │   └── dev/
│   └── modules/
│       ├── ecr/
│       ├── eks/
│       ├── iam/
│       └── network/
└── docs/
```

## Terraform workflow

Create backend resources first:

```bash
cd terraform/bootstrap/backend
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Then use the main environment:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Destroy the main platform after testing:

```bash
terraform destroy
```

## Cost awareness

This project provisions real AWS resources.

Important cost controls in V1:

- EKS is treated as ephemeral
- NAT Gateway is intentionally avoided in the first version
- Node group size is minimal
- ECR lifecycle policy limits stored images
- `terraform destroy` is part of the expected workflow
- ECR uses `force_delete = true` to support complete cleanup after tests
- The backend S3 bucket is intentionally persistent because it stores Terraform state

Do not leave the EKS cluster running after tests.

## Security notes

Current security decisions:

- No static secrets are committed
- `terraform.tfvars` and `tfstate` files are ignored
- Terraform state is stored in a private encrypted S3 bucket
- S3 bucket versioning is enabled for state recovery
- S3 public access is blocked on the backend bucket
- EKS access is managed through EKS Access Entries
- Application container runs as a non-root user
- ECR image scanning is enabled on push
- GitHub Actions uses OIDC for AWS access instead of static AWS keys

## Roadmap

Next iterations:

- Add controlled Terraform plan workflow through GitHub Actions
- Add automated EKS deployment workflow through GitHub Actions
- Add Prometheus and Grafana observability
- Add FastAPI `/metrics`
- Add frontend demo application

## Status

V1 technical foundation is validated.

The project currently demonstrates a complete manual golden path from application code to EKS deployment and full AWS cleanup, with CI validation for the application, Docker image, Helm chart, Terraform configuration, remote Terraform state, and OIDC-based ECR push automation.
