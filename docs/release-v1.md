

# Release V1 Summary

## Purpose

V1 validates a production-inspired golden path for deploying a small FastAPI application to Amazon EKS using Terraform, Docker, ECR, Helm, GitHub Actions, GitHub OIDC, and a remote Terraform backend.

The goal of this release is to demonstrate an end-to-end platform workflow while staying cost-aware and keeping AWS infrastructure ephemeral.

## What V1 demonstrates

```text
Application code
→ automated tests
→ Docker image
→ ECR registry
→ Terraform-managed AWS infrastructure
→ EKS runtime
→ Helm deployment
→ health and readiness validation
→ Prometheus-compatible metrics
→ Terraform destroy
```

## Validated platform capabilities

V1 validates the following capabilities:

```text
FastAPI application
Docker packaging
Amazon ECR image registry
Terraform modules
S3 remote Terraform backend
S3 native state locking
Amazon EKS cluster
Managed node group
Helm deployment
Kubernetes probes
IAM roles
EKS access entries
GitHub Actions CI
GitHub OIDC authentication
Manual ECR push workflow
Manual Terraform Plan workflow
Prometheus-compatible application metrics
Makefile operator commands
Cost-aware destroy workflow
```

## Application layer

The Incident API exposes:

```text
GET /health
GET /ready
GET /metrics
GET /incidents
POST /incidents
```

The `/metrics` endpoint uses `prometheus-client` and exposes Prometheus-compatible metrics, including:

```text
incident_api_info
http_requests_total
```

HTTP requests are counted through a FastAPI middleware using method, path, and status code labels.

## Infrastructure layer

Terraform provisions the main AWS environment:

```text
VPC
Public subnets
Internet Gateway
ECR repository
EKS cluster
Managed node group
IAM roles
EKS access entries
GitHub OIDC provider
GitHub Actions IAM roles
```

The Terraform backend is created separately under:

```text
terraform/bootstrap/backend
```

The backend uses:

```text
S3 remote state
S3 native lockfile
S3 bucket versioning
S3 server-side encryption
S3 public access block
```

DynamoDB locking is intentionally not used because the older `dynamodb_table` backend parameter is deprecated.

## CI/CD layer

Automatic workflows run on push and pull request:

```text
Python CI
Docker CI
Platform CI
```

Manual AWS workflows are separated to avoid cloud side effects on every push:

```text
OIDC Smoke Test
ECR Push
Terraform Plan
```

The Terraform Plan workflow uses GitHub OIDC to assume a dedicated AWS IAM role and run `terraform plan` without static AWS credentials.

## Observability V1

V1 includes an application-level observability foundation:

```text
FastAPI /metrics endpoint
prometheus-client metrics generation
http_requests_total counter
incident_api_info gauge
Helm Prometheus scrape annotations
Platform CI validation for annotations
Makefile observability validation
```

The Helm chart adds pod annotations for future Prometheus discovery:

```yaml
prometheus.io/scrape: "true"
prometheus.io/path: "/metrics"
prometheus.io/port: "8000"
```

Prometheus and Grafana are not deployed in V1.

## Operator workflow

Common local validation commands:

```bash
make app-test
make app-metrics
make helm-validate
make observability-check
```

Main Terraform workflow:

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
terraform destroy
```

After a full destroy of the `dev` environment, the minimum CI/CD foundation can be recreated without provisioning EKS:

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

This recreates ECR, GitHub OIDC provider, GitHub Actions IAM roles, and IAM policies.

## Cost controls

V1 is intentionally cost-aware:

```text
EKS is treated as ephemeral
Terraform destroy is part of the workflow
No NAT Gateway in V1
Minimal managed node group size
ECR lifecycle policy limits stored images
ECR force delete supports full cleanup
S3 backend remains persistent for Terraform state
```

The EKS cluster should not be left running after validation.

## Security decisions

V1 includes the following security decisions:

```text
No static AWS keys in GitHub Actions
GitHub OIDC for AWS authentication
Separate IAM roles per workflow purpose
EKS access managed through access entries
Application container runs as non-root
ECR image scanning enabled on push
Terraform state stored in encrypted private S3 bucket
Terraform variable and state files ignored by Git
Manual AWS workflows to avoid accidental cloud changes
```

## Known limitations

V1 intentionally does not include:

```text
Production ingress
HTTPS termination
Prometheus deployment
Grafana deployment
Automated EKS deployment from CI
Frontend application
Protected GitHub deployment environments
Fully custom least-privilege Terraform Plan IAM policy
```

These items are candidates for later iterations.

## Suggested demo path

A short V1 demo can follow this order:

```text
1. Show README and architecture
2. Run make app-test
3. Run make observability-check
4. Show GitHub Actions CI status
5. Explain GitHub OIDC workflows
6. Explain Terraform remote backend
7. Explain ephemeral EKS lifecycle
8. Show destroy checklist and cost controls
```

A full AWS demo can additionally include:

```text
1. Recreate CI foundation if needed
2. Push Docker image to ECR
3. terraform apply
4. helm deploy
5. port-forward service
6. curl /health, /ready, /metrics
7. terraform destroy
```

## Next iterations

### V2 — Observability stack

```text
Deploy Prometheus with Helm
Deploy Grafana with Helm
Scrape the Incident API /metrics endpoint
Create a basic dashboard
Document observability runbooks
```

### V3 — Controlled deployment automation

```text
Manual GitHub Actions deployment workflow
GitHub environment approval gates
OIDC deployment role
Helm deployment from CI
Post-deployment health checks
```

### V4 — IAM hardening

```text
Replace broad ReadOnlyAccess with custom Terraform Plan policy
Review IAM trust policies
Split permissions by workflow purpose
Document threat model
```

### V5 — Frontend platform demo

```text
React + Vite frontend
Frontend Docker image
Frontend Helm chart
API + frontend deployment path
End-to-end demo architecture
```

## Interview summary

V1 demonstrates a complete platform engineering workflow: infrastructure provisioning with Terraform, remote state management, EKS deployment, Docker/ECR image flow, Helm-based Kubernetes delivery, GitHub Actions CI, OIDC-based AWS authentication, application health checks, Prometheus-compatible metrics, and a cost-aware destroy process.

The platform is intentionally ephemeral and operator-friendly, with Makefile commands and documentation designed to make the workflow reproducible, explainable, and safe to demonstrate.