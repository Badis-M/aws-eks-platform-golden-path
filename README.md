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
GitHub Actions deploy role
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
| CI/CD | GitHub Actions, workflow_dispatch, GitHub Environments |
| Cost control | Ephemeral infrastructure, Terraform destroy, no NAT Gateway in V1 |

## Current status

-Implemented and validated:

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
- Makefile commands for local validation, observability checks, and CI/CD foundation recovery
- kube-prometheus-stack deployed on EKS for V2 observability validation
- ServiceMonitor-based Prometheus discovery for the Incident API
- Prometheus scraping validated with PromQL queries
- Grafana Explore validated with application request-rate metrics
- Manual Incident API deployment workflow validated through GitHub Actions
- GitHub Environment `dev` support for controlled deployments
- Dedicated least-privilege GitHub Actions deploy role
- EKS access entry for the deploy role mapped to Kubernetes RBAC
- Namespace-scoped Kubernetes RBAC for application deployment
- Commit-SHA Docker image tagging from the deployment workflow
- In-cluster smoke test validating `/health` and `/ready`
- V3 deployment troubleshooting and fixes documented
- Manual deployment workflow validated with observability mode enabled
- ServiceMonitor creation validated from the deployment workflow
- Grafana Explore validated after V3 manual deployment

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
| Deploy Incident API | Manual | Builds, pushes, deploys, and smoke-tests the API on an existing EKS cluster |

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

```text
Deploy Incident API
→ checkout
→ assume AWS deploy role through OIDC
→ verify that the EKS cluster already exists
→ login to Amazon ECR
→ build the Incident API image
→ push the image with the commit SHA tag
→ update kubeconfig
→ deploy with Helm
→ wait for the Kubernetes rollout
→ run an in-cluster smoke test against /health and /ready
```

CI runs automatically, but EKS deployment is intentionally manual. The deployment workflow uses `workflow_dispatch` and can be protected with the GitHub Environment named `dev`.

## Observability

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

V2 adds a Kubernetes observability stack on EKS:

```text
kube-prometheus-stack
→ Prometheus Operator
→ Prometheus
→ Grafana
→ kube-state-metrics
→ node-exporter
```

The Incident API chart supports an optional `ServiceMonitor` for Prometheus Operator discovery. It is disabled by default so the application can still deploy without the Prometheus CRDs installed.

Standard deployment mode:

```text
serviceMonitor.enabled = false
```

Observability deployment mode:

```text
serviceMonitor.enabled = true
```

The V2 observability stack was validated end-to-end:

```text
FastAPI /metrics
→ ServiceMonitor
→ Prometheus scrape
→ PromQL query
→ Grafana Explore visualization
```

### Observability demo

The screenshot below shows Grafana Explore querying Prometheus metrics scraped from the Incident API through a `ServiceMonitor`.

```promql
sum by (path) (
  rate(http_requests_total{namespace="incident-api",path=~"/health|/ready|/metrics"}[5m])
)
```

This validates that Prometheus collects application metrics from EKS and that Grafana can visualize request rates by route.

### V3 observability deployment mode

V3 also validates observability through the manual deployment workflow.

When the workflow is triggered with:

```text
enable_observability: true
```

Helm loads:

```text
observability/incident-api-observability-values.yaml
```

This creates the Incident API `ServiceMonitor` from the GitHub Actions deploy workflow.

The validated V3 observability path is:

```text
GitHub Actions manual deployment
→ Helm observability values
→ ServiceMonitor created in incident-api
→ Prometheus scrape
→ PromQL query
→ Grafana Explore visualization
```

This confirms that the deployment workflow supports both standard application deployment and observability-enabled deployment.

![Grafana HTTP request rate](docs/images/grafana-http-request-rate.png)

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

## Manual deployment workflow

V3 adds a controlled manual deployment workflow for the Incident API.

The workflow is triggered with:

```text
workflow_dispatch
```

It is designed to deploy only to an existing EKS cluster. Infrastructure creation remains an explicit operator action performed locally with Terraform.

The manual deployment flow is:

```text
Operator
→ make tf-apply
→ make kubeconfig
→ kubectl apply -f kubernetes/rbac/github-actions-deploy.yaml
→ GitHub Actions Deploy Incident API workflow
→ Helm deployment
→ rollout check
→ in-cluster smoke test
```

The workflow does not run:

```text
terraform apply
terraform destroy
eks create-cluster
eks delete-cluster
```

The deployment workflow uses a dedicated IAM role:

```text
aws-eks-platform-golden-path-dev-github-actions-deploy
```

This role is authenticated into EKS through an EKS access entry and authorized through namespace-scoped Kubernetes RBAC.

The Kubernetes group used by the access entry is:

```text
incident-api-deployers
```

The deploy role can manage application resources in the `incident-api` namespace, but it cannot administer the cluster or create namespaces.

The workflow supports an explicit observability input:

```text
enable_observability: false | true
```

When observability is enabled, Helm also loads:

```text
observability/incident-api-observability-values.yaml
```

This enables the ServiceMonitor mode used by Prometheus Operator.

The observability-enabled mode has been validated end-to-end with ServiceMonitor creation, Prometheus scraping, and Grafana Explore queries.

The full V3 runbook is available in:

```text
docs/deployment-v3-runbook.md
```

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
Deploy role does not create or destroy EKS infrastructure
Deploy role is constrained by namespace-scoped Kubernetes RBAC
```

Current GitHub OIDC roles:

```text
github-actions-ecr-push
→ pushes Docker images to ECR

github-actions-terraform-plan
→ runs Terraform plan with read-oriented AWS permissions

github-actions-deploy
→ deploys the Incident API to an existing EKS cluster
```

## CI/CD dependencies after destroy

A full `terraform destroy` from `terraform/environments/dev` removes the AWS resources required by manual AWS GitHub Actions workflows:

```text
GitHub OIDC provider
GitHub Actions Terraform Plan IAM role
GitHub Actions ECR Push IAM role
GitHub Actions deploy IAM role
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

To recreate only the required CI/CD foundation without provisioning EKS, use the Makefile target:

```bash
make ci-foundation-apply
```

Equivalent Terraform command:
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
GitHub Actions deploy role
IAM policies
```

This does not recreate the EKS cluster.

The S3 remote backend is managed separately by:

```text
terraform/bootstrap/backend
```

The backend should usually remain available even when the ephemeral `dev` environment is destroyed.

## Makefile workflow

The repository includes a Makefile to provide operator-friendly commands for local validation, Helm checks, Terraform operations, and AWS workflow prerequisites.

Common local validation commands:

```bash
make app-test
make app-metrics
make helm-validate
make observability-check
```

Observability validation:

```text
make app-metrics
→ runs the pytest metrics test

make helm-validate
→ runs helm lint, renders standard and observability Helm modes, validates Prometheus scrape annotations, and validates ServiceMonitor behavior

make observability-check
→ runs both app and Helm observability checks
```

Some commands require AWS resources to exist:

```text
ecr-login and ecr-build-push
→ require the ECR repository

OIDC Smoke Test, ECR Push, and Terraform Plan workflows
→ require the GitHub OIDC provider and IAM roles

kubeconfig, kube-pods, helm-deploy, helm-deploy-observability, and helm-uninstall
→ require the EKS cluster
```

After a full `terraform destroy` of the `dev` environment, the minimum CI/CD foundation can be recreated without provisioning EKS:

```bash
make ci-foundation-apply
```

Equivalent Terraform command:

```bash
cd terraform/environments/dev
terraform apply \
  -target=module.ecr \
  -target=module.iam
```

This recreates ECR, the GitHub OIDC provider, GitHub Actions IAM roles, and related IAM policies.

## Repository structure

```text
.
├── apps/
│   └── incident-api/
├── helm/
│   └── incident-api/
├── observability/
│   ├── incident-api-observability-values.yaml
│   └── kube-prometheus-stack-values.yaml
├── kubernetes/
│   └── rbac/
│       └── github-actions-deploy.yaml
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
    ├── deployment-v3-design.md
    ├── deployment-v3-runbook.md
    └── images/
        └── grafana-http-request-rate.png
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

Destroy the main platform after testing from the repository root:

```bash
make tf-destroy
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
- GitHub Actions deployment is manual and environment-aware
- GitHub Actions deploy role is not a cluster admin
- Kubernetes RBAC limits the deploy role to the `incident-api` namespace
- The deploy workflow does not create or destroy EKS infrastructure
- Terraform Plan is manual and non-destructive
- Terraform Plan uses a committed non-sensitive `terraform.ci.tfvars` file
- Terraform Plan workflow is protected with GitHub Actions concurrency
- Application metrics are exposed through `prometheus-client` without requiring external credentials
- Makefile help documents which commands require AWS resources before execution

## Roadmap

Next iterations:

- Add a V3 release note and tag `v3.0.0`
- Add frontend demo application
- Add least-privilege custom IAM policy for Terraform Plan
- Add optional protected approval rules for the GitHub Environment `dev`

## Status

V1 validates the platform foundation: FastAPI, Docker, ECR, Terraform, EKS, Helm, GitHub Actions, GitHub OIDC, S3 remote backend, and cost-aware cleanup.

V2 validates Kubernetes observability with kube-prometheus-stack, Prometheus, Grafana, ServiceMonitor discovery, Prometheus scraping, and Grafana Explore visualization.

V3 validates controlled manual deployment automation. CI runs automatically, but application deployment is triggered manually through GitHub Actions. The workflow assumes a least-privilege AWS role through OIDC, deploys only to an existing EKS cluster, pushes commit-tagged images to ECR, deploys with Helm, and validates the application with an in-cluster smoke test. The same workflow has also been validated with observability mode enabled, including ServiceMonitor creation, Prometheus scraping, and Grafana Explore queries.

The current project demonstrates a secure, cost-aware, and interview-ready platform golden path from application code to EKS deployment, observability validation, and full AWS cleanup.
