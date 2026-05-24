# Destroy Checklist

## Purpose

This checklist ensures that the ephemeral AWS lab is fully cleaned up after each test session.

The goal is to avoid leaving paid AWS resources running.

## Standard destroy command

From the repository root:

```bash
make tf-destroy
```

Or manually:

```bash
cd terraform/environments/dev
terraform destroy
```

Confirm with:

```text
yes
```

## Post-destroy checks

### 1. Check EKS cluster

```bash
aws eks describe-cluster \
  --region eu-west-3 \
  --name aws-eks-platform-golden-path-dev-eks \
  --profile tf-eks-golden-path
```

Expected result:

```text
ResourceNotFoundException
```

### 2. Check ECR repositories

```bash
aws ecr describe-repositories \
  --region eu-west-3 \
  --profile tf-eks-golden-path
```

Expected result:

```text
No incident-api repository
```

### 3. Check Terraform state

```bash
cd terraform/environments/dev
terraform state list
```

Expected result:

```text
No managed resources
```

### 4. Check Kubernetes context

After EKS destroy, this command should fail or show that the cluster is unreachable:

```bash
kubectl get nodes
```

Expected result:

```text
Unable to connect
```

## GitHub OIDC and CI dependencies

A full `terraform destroy` from `terraform/environments/dev` removes the AWS resources required by GitHub Actions AWS workflows.

Destroyed CI/CD dependencies include:

```text
GitHub OIDC provider
GitHub Actions Terraform Plan IAM role
GitHub Actions ECR Push IAM role
IAM trust policies
IAM permission policies
ECR repository
```

After a full destroy, these manual workflows will fail until the minimum CI/CD AWS foundation is recreated:

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

This does **not** recreate:

```text
VPC
EKS cluster
Managed node group
Kubernetes workloads
```

The S3 remote backend is managed separately by:

```text
terraform/bootstrap/backend
```

The backend bucket should remain available unless the backend itself is intentionally retired.

## Backend resources that should usually remain

The S3 backend is not part of the ephemeral EKS runtime.

It stores the Terraform state and supports state locking through the S3 native lockfile.

Do not destroy the backend stack during normal lab cleanup:

```text
terraform/bootstrap/backend
```

Only destroy it when intentionally retiring the project or migrating the backend elsewhere.

## If ECR destroy fails

If Terraform returns:

```text
RepositoryNotEmptyException
```

ensure the ECR repository resource contains:

```hcl
force_delete = true
```

Then run:

```bash
terraform apply
terraform destroy
```

## If Terraform state lock is stuck

If a workflow or local Terraform command is interrupted, the remote state lock may remain active.

Example error:

```text
Error acquiring the state lock
```

First, verify that no local Terraform command or GitHub Actions Terraform workflow is still running.

Then unlock only if the lock is confirmed to be orphaned:

```bash
cd terraform/environments/dev

export AWS_PROFILE=tf-eks-golden-path

terraform force-unlock <LOCK_ID>
```

Do not use `-lock=false` for normal workflows.

## Files that must not be committed

Before pushing:

```bash
git status --ignored
git ls-files | grep -E "tfstate|tfvars|credentials|secret|\.env|\.terraform"
```

Allowed:

```text
terraform/bootstrap/backend/.terraform.lock.hcl
terraform/bootstrap/backend/terraform.tfvars.example
terraform/environments/dev/.terraform.lock.hcl
terraform/environments/dev/terraform.tfvars.example
terraform/environments/dev/terraform.ci.tfvars
```

Not allowed:

```text
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
.env
.terraform/
AWS credentials
```

## Final expected state after full dev destroy

```text
EKS destroyed
Node group destroyed
ECR destroyed
GitHub OIDC provider destroyed
GitHub Actions IAM roles destroyed
Terraform dev state empty
S3 backend still available
No local secrets committed
Git working tree clean
```

## Interview summary

The platform follows an ephemeral workflow: provision, deploy, validate, and destroy. Cleanup is treated as part of the delivery process, not as an afterthought.

The Terraform backend is separated from the ephemeral environment. A full destroy of the `dev` environment removes the OIDC and IAM resources required by manual AWS GitHub Actions workflows, so the minimum CI/CD foundation can be recreated independently with targeted Terraform when needed.
