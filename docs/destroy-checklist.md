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
aws eks describe-cluster   --region eu-west-3   --name aws-eks-platform-golden-path-dev-eks   --profile tf-eks-golden-path
```

Expected result:

```text
ResourceNotFoundException
```

### 2. Check ECR repositories

```bash
aws ecr describe-repositories   --region eu-west-3   --profile tf-eks-golden-path
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

## Files that must not be committed

Before pushing:

```bash
git status --ignored
git ls-files | grep -E "tfstate|tfvars|credentials|secret|\.env|\.terraform"
```

Allowed:

```text
terraform/environments/dev/.terraform.lock.hcl
terraform/environments/dev/terraform.tfvars.example
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

## Final expected state

```text
EKS destroyed
Node group destroyed
ECR destroyed
Terraform state empty
No local secrets committed
Git working tree clean
```

## Interview summary

The platform follows an ephemeral workflow: provision, deploy, validate, and destroy. Cleanup is treated as part of the delivery process, not as an afterthought.
