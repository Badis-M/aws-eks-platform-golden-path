# Security Model

## Overview

This document describes the security model of the AWS EKS Platform Golden Path project.

The project is a lab environment, but it follows production-inspired security principles:

```text
least privilege
no committed secrets
temporary credentials
explicit IAM boundaries
ephemeral infrastructure
container hardening
CI/CD without static AWS keys
```

## Security goals

The main security goals are:

```text
avoid long-lived credentials
keep AWS permissions scoped
separate local and CI/CD access
make infrastructure reproducible
make cleanup part of the workflow
```

## Local AWS access

Local AWS access is performed through a dedicated AWS CLI profile:

```text
tf-eks-golden-path
```

This isolates the project from other AWS profiles and prevents accidental usage of unrelated credentials.

Local credentials are not committed to the repository.

The following files must remain local:

```text
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
.env
AWS credentials
```

A safe example file is committed instead:

```text
terraform/environments/dev/terraform.tfvars.example
```

## EKS access model

EKS access is managed through EKS Access Entries.

The cluster authentication mode supports:

```text
API_AND_CONFIG_MAP
```

This allows modern EKS API-based access management while keeping compatibility with the legacy `aws-auth` ConfigMap model.

The dedicated project IAM principal is granted EKS access through Terraform-managed configuration.

## GitHub Actions OIDC

GitHub Actions uses OIDC to assume an AWS IAM role without storing static AWS access keys in GitHub Secrets.

### Why OIDC

Without OIDC, GitHub Actions would require long-lived credentials:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Those credentials are risky because they remain valid until manually rotated or deleted.

With OIDC, GitHub Actions receives temporary credentials:

```text
GitHub Actions
→ temporary OIDC token
→ AWS IAM OIDC provider
→ IAM role assumption
→ temporary AWS credentials
```

## OIDC trust boundary

The IAM role trust policy is scoped to the GitHub repository and the `main` branch.

Conceptually, AWS only accepts tokens matching:

```text
repo:Badis-M/aws-eks-platform-golden-path:ref:refs/heads/main
```

This prevents unrelated repositories, branches, or workflows from assuming the role.

## Validated OIDC identity

The OIDC smoke test validates the AWS identity with:

```bash
aws sts get-caller-identity
```

Expected identity pattern:

```text
arn:aws:sts::<ACCOUNT_ID>:assumed-role/aws-eks-platform-golden-path-dev-github-actions-ecr-push/GitHubActions
```

This proves that GitHub Actions successfully assumed the AWS IAM role through OIDC.

## ECR push role

The current GitHub Actions role is limited to ECR image push operations.

It is intentionally not allowed to:

```text
deploy to EKS
run terraform apply
delete infrastructure
manage IAM broadly
access unrelated AWS services
```

## ECR permissions

The role allows only the minimum permissions needed to authenticate and push container images to the `incident-api` ECR repository.

Required registry-level permission:

```text
ecr:GetAuthorizationToken
```

Repository-scoped permissions:

```text
ecr:BatchCheckLayerAvailability
ecr:BatchGetImage
ecr:CompleteLayerUpload
ecr:DescribeRepositories
ecr:InitiateLayerUpload
ecr:PutImage
ecr:UploadLayerPart
```

`ecr:BatchGetImage` and `ecr:DescribeRepositories` are required because Docker Buildx and ECR may check existing image manifests and repository metadata during the push flow.

## Validated CI/CD flow

The validated ECR push flow is:

```text
GitHub Actions workflow_dispatch
→ assume AWS role through OIDC
→ login to Amazon ECR
→ setup Docker Buildx
→ build linux/amd64 image
→ push tags to ECR
```

The workflow pushes:

```text
0.1.0
commit SHA tag
```

This provides both a human-readable version tag and an immutable traceable tag.

## Container security

The application container is designed with basic hardening:

```text
non-root runtime user
no secrets baked into the image
minimal runtime dependencies
health endpoints exposed explicitly
```

The Docker image is validated by CI before being pushed to ECR.

## CI security model

Current CI workflows:

```text
Python CI
Docker CI
Platform CI
OIDC Smoke Test
ECR Push
```

Only the AWS-related workflows require OIDC permissions.

The baseline validation workflows do not require AWS access:

```text
Python CI
Docker CI
Platform CI
```

This reduces unnecessary cloud exposure during normal validation.

## Terraform state security

The current project still uses local Terraform state for the V1 lab.

Local state files are ignored by Git:

```text
terraform.tfstate
terraform.tfstate.backup
.terraform/
```

Future improvement:

```text
S3 remote backend
DynamoDB state locking
encryption at rest
restricted state access
```

## Cleanup model

The project is ephemeral.

After validation, AWS resources should be destroyed:

```bash
terraform destroy
```

Validated cleanup includes:

```text
EKS destroyed
ECR destroyed
IAM/OIDC resources destroyed
Terraform state empty
```

The ECR repository uses:

```hcl
force_delete = true
```

so it can be deleted even when images exist.

## Security tradeoffs

| Area | Current state | Future improvement |
|---|---|---|
| Local AWS access | Dedicated IAM profile | AWS SSO or role assumption |
| CI AWS access | GitHub OIDC | Separate roles per workflow |
| Terraform state | Local state | Remote S3 backend with locking |
| EKS deployment | Manual | Protected deployment workflow |
| ECR push | Manual workflow_dispatch | Controlled release workflow |
| Secrets | Not used yet | AWS Secrets Manager + External Secrets Operator |
| Image security | ECR scan on push | CI vulnerability gate |

## Future improvements

Planned security improvements:

```text
separate IAM roles for plan, deploy, and destroy
remote Terraform backend with state locking
GitHub protected environments
manual approval gates for deployment
AWS Secrets Manager integration
External Secrets Operator
image vulnerability scanning gates
Kubernetes network policies
```

## Interview summary

This project uses GitHub Actions OIDC to let CI/CD workflows assume a scoped AWS IAM role with temporary credentials. The ECR push workflow has been validated without storing AWS access keys in GitHub, and permissions are limited to the container registry workflow only.
