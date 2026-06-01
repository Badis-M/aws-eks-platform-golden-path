# Cost Control Runbook

This runbook explains how to control AWS costs for the AWS EKS Platform Golden
Path.

The platform is designed to be ephemeral: create infrastructure for validation,
test the capability, then destroy the environment.

## Cost-control principles

The project follows these principles:

- infrastructure is created intentionally with Terraform
- application deployment does not create AWS infrastructure
- EKS is not kept running without a reason
- public LoadBalancers are avoided by default
- observability access uses port-forwarding
- cleanup is part of the operating model
- post-destroy verification is required

## Main cost drivers

The main resources to watch are:

| Resource | Cost risk |
| --- | --- |
| EKS cluster | hourly control plane cost |
| EC2 worker nodes | compute cost while running |
| EBS volumes | storage cost if left unattached |
| LoadBalancers | hourly and traffic cost |
| NAT Gateways | high hourly and data processing cost |
| Elastic IPs | cost if allocated and unused |
| ECR images | storage cost over time |

## Normal cleanup flow

Remove application and observability resources first.

```bash
make helm-uninstall
make observability-uninstall
kubectl delete namespace incident-api --ignore-not-found
kubectl delete namespace observability --ignore-not-found
```

Then destroy AWS infrastructure.

```bash
make tf-destroy
```

Confirm the Terraform destroy prompt with:

```text
yes
```

## Post-cleanup verification

Run the cleanup verification script after `terraform destroy`.

```bash
AWS_PROFILE=tf-eks-golden-path \
AWS_REGION=eu-west-3 \
./scripts/check-aws-cleanup.sh
```

The script checks for common remaining cost drivers:

- EKS cluster
- Elastic LoadBalancers
- NAT Gateways
- EC2 instances
- unattached EBS volumes
- Elastic IPs
- ECR images

## Manual verification commands

Check that the EKS cluster no longer exists.

```bash
aws eks describe-cluster \
  --region eu-west-3 \
  --profile tf-eks-golden-path \
  --name aws-eks-platform-golden-path-dev-eks
```

Expected result:

```text
ResourceNotFoundException
```

Check EC2 instances.

```bash
aws ec2 describe-instances \
  --region eu-west-3 \
  --profile tf-eks-golden-path \
  --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,Type:InstanceType}' \
  --output table
```

Check LoadBalancers.

```bash
aws elbv2 describe-load-balancers \
  --region eu-west-3 \
  --profile tf-eks-golden-path \
  --query 'LoadBalancers[].LoadBalancerName' \
  --output table
```

Check NAT Gateways.

```bash
aws ec2 describe-nat-gateways \
  --region eu-west-3 \
  --profile tf-eks-golden-path \
  --filter Name=state,Values=pending,available \
  --query 'NatGateways[].{Id:NatGatewayId,State:State,VpcId:VpcId}' \
  --output table
```

Check unattached EBS volumes.

```bash
aws ec2 describe-volumes \
  --region eu-west-3 \
  --profile tf-eks-golden-path \
  --filters Name=status,Values=available \
  --query 'Volumes[].{Id:VolumeId,Size:Size,Type:VolumeType,State:State}' \
  --output table
```

Check Elastic IPs.

```bash
aws ec2 describe-addresses \
  --region eu-west-3 \
  --profile tf-eks-golden-path \
  --query 'Addresses[].{PublicIp:PublicIp,AllocationId:AllocationId,AssociationId:AssociationId}' \
  --output table
```

Check ECR images.

```bash
aws ecr describe-images \
  --region eu-west-3 \
  --profile tf-eks-golden-path \
  --repository-name incident-api \
  --query 'imageDetails[].{Digest:imageDigest,Tags:imageTags,PushedAt:imagePushedAt}' \
  --output table
```

## When a resource remains

If a resource remains after cleanup, do not delete randomly first.

Recommended process:

```text
identify resource
-> check whether Terraform should own it
-> check tags
-> check dependencies
-> delete through Terraform if possible
-> delete manually only if it is orphaned
-> rerun cleanup verification
```

## ECR cleanup note

ECR can retain pushed images if the repository remains.

If the repository is Terraform-managed and should be removed, prefer:

```bash
make tf-destroy
```

If the repository is intentionally kept, delete old images periodically or add
an ECR lifecycle policy.

## Cost-aware validation sessions

Recommended session flow:

```text
create infra
-> validate feature
-> document result
-> destroy infra
-> run cleanup verification
```

Do not leave EKS running overnight unless there is a clear reason.

## Final cleanup criteria

Cleanup is complete when:

- Terraform destroy completed successfully
- EKS cluster no longer exists
- no EC2 worker nodes remain
- no LoadBalancers remain
- no NAT Gateways remain
- no unattached EBS volumes remain
- no unused Elastic IPs remain
- ECR is either empty or intentionally retained
- the cleanup verification script passes
