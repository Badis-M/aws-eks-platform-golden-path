# Security Model

## Overview

This document describes the current security posture of the AWS EKS Platform Golden Path project.

The project is a lab environment, but it follows security-first principles where possible:

```text
least privilege
no committed secrets
ephemeral infrastructure
explicit IAM boundaries
container hardening
CI without AWS credentials
```

## Identity and access

Local AWS access is performed through a dedicated AWS CLI profile:

```text
tf-eks-golden-path
```

This keeps the project isolated from other AWS labs or personal profiles.

## EKS access model

EKS access is managed through EKS Access Entries instead of relying only on manual Kubernetes configuration.

The cluster authentication mode supports:

```text
API_AND_CONFIG_MAP
```

This allows modern EKS access management while keeping compatibility with the legacy `aws-auth` mechanism.

## IAM roles

Terraform manages IAM roles for:

```text
EKS control plane
EKS managed node group
EKS cluster access
```

The node group has permission to pull images from ECR through AWS-managed ECR read-only permissions.

## Secrets handling

The repository must not contain:

```text
AWS access keys
terraform.tfvars
terraform.tfstate
.env files
local credentials
```

The `.gitignore` excludes sensitive local files such as:

```text
terraform.tfvars
terraform.tfstate
.terraform/
.env
```

A safe example variables file is committed instead:

```text
terraform/environments/dev/terraform.tfvars.example
```

## Container security

The FastAPI container is designed to avoid running as root.

Current container hardening decisions:

```text
non-root runtime user
minimal Python runtime image
no secrets baked into the image
health endpoints exposed explicitly
```

## CI security

GitHub Actions currently runs validation only:

```text
Python tests
Docker build
Helm validation
Terraform validation
```

Current workflows do not access AWS and do not require cloud credentials.

## Planned security improvements

Next improvements:

```text
GitHub Actions OIDC for AWS access
least-privilege IAM role for CI/CD
remote Terraform state with locking
AWS Secrets Manager integration
External Secrets Operator for Kubernetes
image vulnerability gates
container scanning in CI
```

## Security tradeoffs

| Area | Current state | Future improvement |
|---|---|---|
| AWS local access | IAM user/profile | AWS SSO or short-lived role assumption |
| Terraform state | Local state | Remote backend with locking |
| Kubernetes secrets | Not used yet | AWS Secrets Manager + External Secrets |
| CI deployment | Not implemented | OIDC + scoped IAM role |
| Ingress | Not exposed publicly | HTTPS ingress with controlled access |

## Key principle

The project uses AWS CLI and Terraform locally for the first version, but long-lived cloud credentials should not be used in CI/CD. Future deployment automation must use OIDC and short-lived credentials.
