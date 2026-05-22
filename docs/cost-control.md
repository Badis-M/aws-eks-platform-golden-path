# Cost Control

## Overview

This project provisions real AWS resources. Cost control is part of the design.

The platform is intentionally ephemeral:

```text
provision
deploy
validate
destroy
```

The expected behavior is to destroy all AWS resources after each test session.

## Main cost drivers

| Resource | Cost risk |
|---|---|
| EKS cluster | High if left running |
| EC2 worker node | Medium if left running |
| NAT Gateway | High, intentionally avoided |
| LoadBalancer | Avoided in V1 |
| ECR storage | Low but not zero |
| Data transfer | Low in this lab |

## Cost-aware design decisions

### No NAT Gateway in V1

The first version avoids NAT Gateway to reduce unnecessary cost.

This is acceptable for the lab because the architecture is intentionally small and short-lived.

### Minimal node group

The EKS node group uses a minimal size:

```text
desired = 1
min     = 1
max     = 1
```

This keeps compute cost controlled while still demonstrating managed Kubernetes.

### No public LoadBalancer in V1

The API is validated through:

```bash
kubectl port-forward
```

This avoids creating an AWS Load Balancer during early iterations.

### ECR lifecycle policy

The ECR repository keeps only a small number of images to limit storage usage.

Terraform also uses:

```hcl
force_delete = true
```

so the repository can be deleted even when it contains images.

## Destroy workflow

After each test session:

```bash
make tf-destroy
```

or:

```bash
cd terraform/environments/dev
terraform destroy
```

Expected final checks:

```bash
aws eks describe-cluster --name aws-eks-platform-golden-path-dev-eks
aws ecr describe-repositories
terraform state list
```

Expected results:

```text
EKS cluster not found
No incident-api ECR repository
Empty Terraform state
```

## Cost warning

Do not leave the EKS cluster running after tests.

EKS is not free-tier. This project is free-tier-aware, but not entirely free if resources are left running.

## Future improvements

Planned cost-control improvements:

```text
automatic destroy workflow
budget alerts
cost tags
AWS Cost Explorer review notes
scheduled cleanup checks
optional TTL label strategy
```

## Interview summary

This project is designed as an ephemeral platform lab. The infrastructure is created only when needed, validated end-to-end, then destroyed to avoid ongoing AWS costs.
