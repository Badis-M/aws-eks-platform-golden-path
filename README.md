# AWS EKS Platform Golden Path

A production-inspired DevOps / SRE / Platform Engineering lab that demonstrates how to provision, deploy, validate, and destroy an ephemeral Kubernetes platform on AWS.

The project is designed to stay cost-aware while still covering real platform engineering concerns: Terraform modules, EKS, ECR, Helm, Docker, IAM, Kubernetes access management, application health checks, GitHub Actions OIDC, and reproducible workflows.

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
  | docker buildx
  v
AWS ECR
  |
  | image pull
  v
Amazon EKS
  |
  | Helm chart
  v
FastAPI Incident API
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

Helm deploys:

```text
Deployment
Service
Readiness probe
Liveness probe
CPU / memory requests and limits
```

## Technology stack

| Area | Tools |
|---|---|
| Cloud | AWS |
| Kubernetes | Amazon EKS |
| Infrastructure as Code | Terraform |
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

Current CI checks:

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

Validated identity example:

```text
arn:aws:sts::<ACCOUNT_ID>:assumed-role/aws-eks-platform-golden-path-dev-github-actions-ecr-push/GitHubActions
```

## Repository structure

```text
.
├── apps/
│   └── incident-api/
├── helm/
│   └── incident-api/
├── terraform/
│   ├── environments/
│   │   └── dev/
│   └── modules/
│       ├── ecr/
│       ├── eks/
│       ├── iam/
│       └── network/
└── docs/
```

## Local application workflow

```bash
cd apps/incident-api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pytest
```

Run locally:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Validate:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/ready
```

## Docker workflow

Build locally:

```bash
docker build -t incident-api:0.1.0 apps/incident-api
```

For EKS nodes using x86_64 instances, build and push an AMD64 image:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t <ACCOUNT_ID>.dkr.ecr.eu-west-3.amazonaws.com/incident-api:0.1.0 \
  apps/incident-api \
  --push
```

## Terraform workflow

Create a local variables file:

```bash
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
```

Edit:

```text
terraform/environments/dev/terraform.tfvars
```

Then run:

```bash
cd terraform/environments/dev
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Destroy after testing:

```bash
terraform destroy
```

To create only the resources needed for OIDC-based ECR push testing:

```bash
terraform apply \
  -target=module.ecr \
  -target=module.iam
```

## Helm workflow

Validate the chart:

```bash
helm lint helm/incident-api
helm template incident-api helm/incident-api
```

Deploy to EKS:

```bash
helm upgrade --install incident-api helm/incident-api
```

Validate:

```bash
kubectl get pods
kubectl port-forward service/incident-api-incident-api 8080:80
curl http://localhost:8080/health
curl http://localhost:8080/ready
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

Do not leave the EKS cluster running after tests.

## Security notes

Current security decisions:

- No static secrets are committed
- `terraform.tfvars` and `tfstate` files are ignored
- EKS access is managed through EKS Access Entries
- Application container runs as a non-root user
- ECR image scanning is enabled on push
- Node group has read-only ECR access through IAM
- GitHub Actions uses OIDC for AWS access instead of static AWS keys
- The ECR push role does not grant EKS deployment or Terraform apply permissions

Future improvements:

- Separate IAM roles for plan, deploy, and destroy workflows
- Remote Terraform backend with state locking
- Secrets management through AWS Secrets Manager or External Secrets Operator
- Image vulnerability gates
- Protected GitHub environments for deployment approvals

## Roadmap

Next iterations:

- Add automated EKS deployment workflow through GitHub Actions
- Add controlled Terraform plan workflow
- Add remote Terraform backend with state locking
- Add Prometheus and Grafana observability
- Add FastAPI `/metrics`
- Add frontend demo application
- Add architecture and runbook documentation improvements

## Status

V1 technical foundation is validated.

The project currently demonstrates a complete manual golden path from application code to EKS deployment and full AWS cleanup, with CI validation for the application, Docker image, Helm chart, Terraform configuration, and OIDC-based ECR push automation.
