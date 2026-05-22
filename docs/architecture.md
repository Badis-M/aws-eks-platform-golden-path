# Architecture

## Overview

This project demonstrates an ephemeral AWS EKS golden path for deploying a small FastAPI application with Terraform, Docker, ECR, Helm, and Kubernetes.

The goal is to show a complete platform workflow:

```text
Application code
→ Docker image
→ ECR registry
→ Helm deployment
→ EKS runtime
→ Health validation
→ Terraform destroy
```

The platform is intentionally minimal and cost-aware while still using production-inspired patterns.

## High-level architecture

```text
Developer laptop
  |
  | docker buildx --platform linux/amd64
  v
Amazon ECR
  |
  | image pull through node IAM role
  v
Amazon EKS
  |
  | Helm chart
  v
FastAPI Incident API
```

## Infrastructure layer

Terraform provisions the AWS foundation:

```text
VPC
Public subnets
Internet Gateway
EKS cluster
Managed node group
ECR repository
IAM roles
EKS access entries
```

The first version avoids NAT Gateway to reduce cost and keep the lab suitable for short-lived demonstrations.

## Application layer

The application is a Python FastAPI service exposing:

```text
/health
/ready
/incidents
```

It is packaged as a Docker image and deployed to Kubernetes through Helm.

## Kubernetes layer

Helm deploys:

```text
Deployment
Service
Readiness probe
Liveness probe
CPU and memory requests
CPU and memory limits
```

The Kubernetes service is currently internal and validated through `kubectl port-forward`.

## CI layer

GitHub Actions validates the project through three workflows:

```text
Python CI   → pytest
Docker CI   → docker build
Platform CI → Helm lint/template + Terraform fmt/init/validate
```

The current CI does not deploy to AWS. AWS deployment automation is planned through GitHub Actions OIDC.

## Design choices

| Decision | Reason |
|---|---|
| EKS instead of local Kubernetes only | Demonstrates real managed Kubernetes operations on AWS |
| ECR instead of Docker Hub | Native AWS IAM integration and private registry workflow |
| Helm instead of raw manifests | Reusable and configurable Kubernetes deployment |
| Terraform modules | Reusable infrastructure boundaries |
| No NAT Gateway in V1 | Lower cost for an ephemeral lab |
| Port-forward validation | Avoids LoadBalancer cost in the first version |

## Current limitations

- No production ingress yet
- No HTTPS termination yet
- No observability stack yet
- No remote Terraform backend yet
- No automated AWS deployment from CI yet
- No frontend application yet

These are intentional future iterations, not blockers for the V1 foundation.
