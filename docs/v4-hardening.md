

# V4 Production-Grade Hardening

V4 improves the AWS EKS Platform Golden Path after the validated V3 manual
deployment workflow.

The goal is to make the platform more production-like by strengthening Helm
naming, deployment controls, IAM least privilege, and Kubernetes security
boundaries.

## V4 scope

V4 focuses on practical hardening without changing the core platform model.

The platform still follows these principles:

- CI runs automatically.
- Cloud deployment is manually triggered.
- EKS infrastructure is created intentionally with Terraform.
- GitHub Actions deploys only to an existing cluster.
- AWS authentication uses GitHub OIDC.
- Runtime deployment permissions are constrained by Kubernetes RBAC.

## V4.1 - Helm naming hardening

V4.1 standardizes Kubernetes resource names rendered by the Helm chart.

The chart now supports:

```text
nameOverride
fullnameOverride
```

The deploy workflow sets:

```text
fullnameOverride=incident-api
```

This produces predictable Kubernetes resources:

```text
deployment/incident-api
service/incident-api
servicemonitor/incident-api
```

This replaces the previous default naming pattern:

```text
incident-api-incident-api
```

### Why it matters

Predictable resource names make rollout checks, smoke tests, monitoring, and
documentation easier to operate and less error-prone.

### Validation

Local Helm rendering was validated with:

```bash
helm template incident-api helm/incident-api \
  --namespace incident-api \
  --set fullnameOverride=incident-api
```

Observability rendering was validated with:

```bash
helm template incident-api helm/incident-api \
  --namespace incident-api \
  --set fullnameOverride=incident-api \
  --values observability/incident-api-observability-values.yaml
```

The manual deployment workflow was then validated successfully with the new
resource names.

## V4.2 - GitHub Environment approval

V4.2 protects the manual deployment workflow with GitHub Environment approval.

The deploy job targets:

```text
environment: dev
```

The GitHub Environment `dev` is configured with required reviewers.

The deployment flow is:

```text
workflow_dispatch
-> GitHub Environment dev
-> required reviewer approval
-> GitHub OIDC role assumption
-> EKS deployment
```

### Why it matters

Human approval happens before the AWS deploy role is assumed.

The deployment remains:

- manual
- auditable
- protected
- keyless through GitHub OIDC

This keeps the deployment workflow controlled without storing static AWS
credentials in GitHub.

### Validation

The `dev` environment was configured in GitHub with a required reviewer.

The deploy workflow now requires approval before continuing to AWS role
assumption and EKS deployment.

## V4.3 - Terraform Plan IAM hardening

V4.3 replaces the broad AWS managed policy:

```text
ReadOnlyAccess
```

with a custom Terraform Plan read policy.

The custom policy allows the GitHub Actions Terraform Plan role to read only
the AWS resources required for Terraform refresh and planning.

Covered read areas include:

- caller identity validation
- selected EC2 and VPC metadata
- EKS cluster, node group, and access entry metadata
- ECR repository metadata
- project IAM roles and policies
- AWS managed policies used by the EKS module
- Terraform backend state and lockfile access through a separate S3 policy

### Why it matters

The Terraform Plan workflow remains non-destructive, but now follows a
stronger least-privilege model instead of relying on broad AWS account-wide
read access.

### Real validation issue

During validation, Terraform refresh required this additional permission:

```text
ec2:DescribeVpcAttribute
```

The missing permission appeared when Terraform read the VPC attribute:

```text
enableDnsHostnames
```

The custom IAM policy was updated to include `ec2:DescribeVpcAttribute`, then
the Terraform Plan workflow was validated successfully.

### Validation

The Terraform update applied one IAM policy change:

```text
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

The GitHub Actions Terraform Plan workflow was then validated successfully
with the custom read policy.

## V4.4 - Kubernetes NetworkPolicy intent

V4.4 adds a declarative Kubernetes NetworkPolicy for the `incident-api`
namespace.

The policy is defined in:

```text
kubernetes/networkpolicies/incident-api.yaml
```

It allows ingress to the Incident API pods on port `8000` from:

- the `incident-api` namespace
- the `observability` namespace

It also allows DNS egress to `kube-system` on port `53`.

### Why it matters

The NetworkPolicy documents the intended network security boundary around the
application.

It makes the desired traffic model explicit:

```text
same namespace traffic
observability scraping traffic
DNS egress
```

### Important limitation

On EKS, Kubernetes NetworkPolicy enforcement depends on a compatible policy
engine such as Calico, Cilium, or equivalent.

With the default AWS VPC CNI alone, a Kubernetes NetworkPolicy can be accepted
by the Kubernetes API without necessarily enforcing traffic restrictions.

This V4 step defines the intended network security model and keeps the policy
ready for enforcement when a compatible policy engine is installed.

### Validation

Client-side validation:

```bash
kubectl apply --dry-run=client \
  -f kubernetes/networkpolicies/incident-api.yaml
```

Cluster apply:

```bash
kubectl apply -f kubernetes/networkpolicies/incident-api.yaml
```

Verification:

```bash
kubectl get networkpolicy -n incident-api
```

Expected result:

```text
NAME           POD-SELECTOR
incident-api   app.kubernetes.io/name=incident-api
```

## V4 status

Validated:

- Helm `fullnameOverride` support
- predictable Kubernetes resource naming
- GitHub Environment required reviewer gate
- custom IAM policy for Terraform Plan
- Terraform Plan workflow with least-privilege read permissions
- declarative Incident API NetworkPolicy

## Remaining V4 candidates

Possible next hardening items:

- document NetworkPolicy limitations in the README
- add NetworkPolicy validation to CI
- evaluate a policy engine such as Calico or Cilium
- add V4 release notes
- tag `v4.0.0` when the V4 scope is complete

## Interview explanation

```text
In V4, I started hardening the platform after validating the manual deployment
model. I standardized Helm resource names with fullnameOverride, protected the
deployment workflow with GitHub Environment approval, replaced broad
ReadOnlyAccess with a custom Terraform Plan read policy, and added a
declarative NetworkPolicy to express the intended application network
boundary. This keeps the platform closer to production expectations while
preserving the cost-aware and manual deployment model.
```