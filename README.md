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
GitHub Actions Terraform plan role
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

- FastAPI application with `/health`, `/ready`, `/metrics`, and incident endpoints
- Local Python tests
- Dockerfile using non-root runtime user
- Helm chart with probes, resource limits, and Prometheus scrape annotations
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
- Manual Terraform Plan workflow validated through GitHub OIDC
- Terraform Plan workflow protected against concurrent runs

## Continuous Integration

The repository includes GitHub Actions workflows to validate the main project layers on every push and pull request.

| Workflow | Trigger | Purpose |
|---|---|---|
| Python CI | Push / Pull request | Installs the FastAPI dependencies and runs the pytest test suite |
| Docker CI | Push / Pull request | Builds the Incident API Docker image to validate container packaging |
| Platform CI | Push / Pull request | Validates Helm and Terraform configuration |
| OIDC Smoke Test | Manual | Validates that GitHub Actions can assume an AWS IAM role through OIDC |
| ECR Push | Manual | Builds and pushes the Incident API image to Amazon ECR through OIDC |
| Terraform Plan | Manual | Runs `terraform plan` through OIDC without applying infrastructure changes |

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

Terraform Plan
→ checkout
→ assume AWS IAM role through OIDC
→ terraform init with S3 backend
→ terraform validate
→ terraform plan with CI variables
```

The current CI does not automatically deploy to EKS. AWS deployment automation will be added later through controlled workflows and least-privilege IAM roles.

## Observability V1

The Incident API exposes a Prometheus-compatible metrics endpoint:

```text
GET /metrics
```

Current application metrics:

```text
incident_api_info{app="incident-api",version="0.1.0"} 1.0
http_requests_total{method="GET",path="/health",status_code="200"} 1.0
```

The metrics endpoint is generated with `prometheus-client` and includes a FastAPI middleware that counts HTTP requests by method, path, and status code.

The Helm chart also adds Prometheus scrape annotations to the pod template:

```yaml
prometheus.io/scrape: "true"
prometheus.io/path: "/metrics"
prometheus.io/port: "8000"
```

This prepares the application for a future Prometheus and Grafana deployment.

Prometheus and Grafana are not installed in V1.

## Terraform Plan workflow

The Terraform Plan workflow is manual and intentionally non-destructive.

It is triggered with:

```text
workflow_dispatch
```

It performs:

```text
GitHub Actions
→ OIDC token request
→ AWS IAM role assumption
→ Terraform backend initialization
→ Terraform validation
→ Terraform plan
```

It does not run:

```text
terraform apply
terraform destroy
```

The workflow uses a dedicated IAM role:

```text
aws-eks-platform-golden-path-dev-github-actions-terraform-plan
```

The role is separate from the ECR push role.

Its permissions are intentionally scoped for planning:

```text
AWS ReadOnlyAccess
S3 backend state access
S3 native lockfile access
```

The workflow uses a committed non-sensitive variables file:

```text
terraform/environments/dev/terraform.ci.tfvars
```

This keeps the workflow non-interactive while avoiding duplication of Terraform variables directly inside the GitHub Actions YAML.

The workflow also uses GitHub Actions concurrency:

```text
concurrency group: terraform-plan-dev
```

This prevents multiple Terraform Plan runs from using the same remote state at the same time.

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

This project uses GitHub Actions OIDC to let selected workflows assume AWS IAM roles without storing long-lived AWS access keys in GitHub Secrets.

The current OIDC flow is:

```text
GitHub Actions workflow
→ temporary OIDC token
→ AWS IAM OIDC provider
→ IAM role assumption
→ temporary AWS credentials
→ AWS operation
```

Security properties:

```text
No AWS access keys stored in GitHub
Temporary credentials only
IAM trust scoped to this repository and main branch
Separate roles per workflow purpose
ECR permissions scoped to the incident-api repository
Terraform Plan role does not run apply or destroy
```

Current GitHub OIDC roles:

```text
github-actions-ecr-push
→ pushes Docker images to ECR

github-actions-terraform-plan
→ runs Terraform plan with read-oriented AWS permissions
```

## CI/CD dependencies after destroy

A full `terraform destroy` from `terraform/environments/dev` removes the AWS resources required by manual AWS GitHub Actions workflows:

```text
GitHub OIDC provider
GitHub Actions Terraform Plan IAM role
GitHub Actions ECR Push IAM role
IAM trust policies
IAM permission policies
ECR repository
```

After a full destroy, these workflows will fail until the minimum CI/CD AWS foundation is recreated:

```text
OIDC Smoke Test
ECR Push
Terraform Plan
```

To recreate only the required CI/CD foundation without provisioning EKS:

```bash
cd terraform/environments/dev

terraform apply \
  -target=module.ecr \
  -target=module.iam
```

This recreates:

```text
ECR repository
GitHub OIDC provider
GitHub Actions ECR push role
GitHub Actions Terraform plan role
IAM policies
```

This does not recreate the EKS cluster.

The S3 remote backend is managed separately by:

```text
terraform/bootstrap/backend
```

The backend should usually remain available even when the ephemeral `dev` environment is destroyed.

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

Run a CI-compatible local plan:

```bash
terraform plan \
  -input=false \
  -var-file=terraform.ci.tfvars
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
- GitHub Actions roles are separated by purpose
- Terraform Plan is manual and non-destructive
- Terraform Plan uses a committed non-sensitive `terraform.ci.tfvars` file
- Terraform Plan workflow is protected with GitHub Actions concurrency
- Application metrics are exposed through `prometheus-client` without requiring external credentials

## Roadmap

Next iterations:

- Add automated EKS deployment workflow through GitHub Actions
- Add Prometheus and Grafana deployment on EKS
- Add frontend demo application
- Add protected GitHub environments for deployment approvals
- Add least-privilege custom IAM policy for Terraform Plan

## Status

V1 technical foundation is validated.

The project currently demonstrates a complete manual golden path from application code to EKS deployment and full AWS cleanup, with CI validation for the application, Docker image, Helm chart, Terraform configuration, remote Terraform state, OIDC-based ECR push automation, a manual OIDC-based Terraform Plan workflow, and Prometheus-compatible application metrics.
