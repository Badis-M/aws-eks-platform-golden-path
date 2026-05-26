# Deployment V3 Design

## Purpose

V3 adds controlled application deployment automation to the platform without triggering AWS infrastructure creation on every code change.

The goal is to keep the project cost-aware while demonstrating a realistic platform engineering delivery model:

```text
automatic CI
→ validate code and platform configuration
→ no AWS deployment
→ no EKS creation

manual CD
→ explicit operator action
→ optional GitHub Environment approval
→ deploy application to an existing EKS cluster
→ run post-deployment checks
```

## Problem statement

The platform is intentionally ephemeral. EKS is created only for demos, tests, or validation sessions, then destroyed to control AWS costs.

Because of this, deployment automation must not behave like this:

```text
push to main
→ terraform apply
→ EKS created
→ application deployed
→ AWS cost starts automatically
```

That model would be unsafe for this lab because normal documentation or code commits could trigger paid infrastructure.

V3 must instead separate validation from deployment.

## Target model

### Automatic CI

Automatic workflows continue to run on push and pull request.

They validate:

```text
Python tests
Docker build
Helm lint
Helm template
Terraform fmt
Terraform validate
Terraform plan when explicitly configured
ServiceMonitor rendering modes
```

Automatic CI must not:

```text
create EKS
run terraform apply
run terraform destroy
install Helm releases on AWS
create public endpoints
```

### Manual CD

Deployment automation is triggered manually through GitHub Actions using `workflow_dispatch`.

The operator decides when to deploy.

The expected deployment flow is:

```text
operator creates EKS with make tf-apply
operator triggers GitHub manual deployment workflow
GitHub Actions assumes AWS deploy role through OIDC
workflow builds and pushes the Docker image to ECR
workflow updates kubeconfig for the EKS cluster
workflow deploys the Incident API with Helm
workflow runs post-deployment health checks
operator validates observability if needed
operator destroys the environment with make tf-destroy
```

## High-level architecture

```text
Developer / Operator
  |
  | manual workflow_dispatch
  v
GitHub Actions deploy workflow
  |
  | GitHub OIDC token
  v
AWS IAM deploy role
  |
  ├── ECR push permissions
  ├── EKS describe permissions
  └── Kubernetes deployment through EKS access entry
        |
        v
Amazon EKS existing cluster
  |
  └── Helm upgrade --install incident-api
        |
        v
incident-api namespace
```

## Cost-control principle

V3 must not create infrastructure automatically.

Infrastructure lifecycle remains explicit:

```text
make tf-apply
→ creates temporary AWS infrastructure

manual GitHub deploy workflow
→ deploys the application only if EKS already exists

make tf-destroy
→ destroys AWS infrastructure after validation
```

This keeps cost-generating actions under direct operator control.

## Workflow trigger strategy

The deployment workflow should use:

```yaml
on:
  workflow_dispatch:
```

It should not use:

```yaml
on:
  push:
```

Reason:

```text
push-based deployment could create or modify cloud resources unexpectedly
manual workflow_dispatch keeps deployment intentional
```

## GitHub Environment strategy

V3 should use a GitHub Environment named:

```text
dev
```

Purpose:

```text
add a manual approval gate before deployment
separate deployment workflows from normal CI
make the deployment step visible in GitHub UI
prepare the project for production-like release controls
```

The environment should be used only for deployment workflows, not for normal CI.

## AWS authentication model

V3 continues the existing OIDC model.

The workflow should not use static AWS access keys.

Expected flow:

```text
GitHub Actions
→ requests OIDC token
→ assumes AWS IAM deploy role
→ receives short-lived AWS credentials
→ pushes image to ECR
→ configures kubeconfig
→ deploys with Helm
```

Security properties:

```text
no long-lived AWS credentials in GitHub Secrets
short-lived credentials only
trust policy scoped to this repository
role assumption limited to selected branch and workflow context
```

## IAM deploy role design

V3 should add a dedicated IAM role:

```text
github-actions-deploy
```

This role should be separate from:

```text
github-actions-ecr-push
github-actions-terraform-plan
```

Reason:

```text
separation of duties
clear permission boundaries
simpler auditing
safer future hardening
```

The deploy role should use least-privilege AWS permissions.

Initial AWS permissions should include only:

```text
sts:GetCallerIdentity
eks:DescribeCluster
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
```

ECR permissions should be scoped to the `incident-api` repository when the AWS API supports resource-level scoping.

The deploy role must not have:

```text
eks:CreateCluster
eks:DeleteCluster
ec2:*
iam:*
AdministratorAccess
Terraform apply permissions
```

Kubernetes permissions should be handled through EKS access entries and namespace-scoped Kubernetes RBAC, not broad AWS or Kubernetes admin permissions.

## Kubernetes access model

V3 separates AWS identity management from Kubernetes authorization.

Terraform is responsible for AWS-side identity resources:

```text
IAM deploy role
least-privilege IAM policy
EKS access entry
```

Versioned Kubernetes manifests are responsible for namespace-scoped RBAC:

```text
kubernetes/rbac/github-actions-deploy.yaml
```

This avoids adding the Terraform Kubernetes provider in V3 and keeps the separation between AWS IAM and Kubernetes RBAC explicit.

The deploy role needs access to the EKS cluster for Helm deployment, but it should not receive cluster-wide admin permissions.

Expected mechanism:

```text
Terraform
→ creates IAM deploy role
→ attaches least-privilege AWS policy
→ creates EKS access entry for the deploy role

Kubernetes YAML
→ creates Role in namespace incident-api
→ creates RoleBinding in namespace incident-api
→ binds the deploy identity to namespace-scoped permissions
```

The deploy identity should be allowed to manage only the resources required by the Incident API Helm release.

Initial namespace-scoped Kubernetes permissions:

```text
get/list/watch/create/update/patch/delete
```

Target resource groups:

```text
core:
  services
  configmaps
  secrets
  serviceaccounts
  pods

actions:
  deployments
  replicasets

monitoring.coreos.com:
  servicemonitors
```

The `monitoring.coreos.com` permissions are required only for the observability deployment mode where the `ServiceMonitor` is enabled.

The deploy role should not have permissions to manage:

```text
nodes
namespaces
clusterroles
clusterrolebindings
customresourcedefinitions
persistentvolumes
storageclasses
other application namespaces
```

This keeps the deployment workflow limited to the `incident-api` namespace.

## Deployment target

The application should deploy to:

```text
namespace: incident-api
release: incident-api
chart: helm/incident-api
```

V3 should use the existing Makefile and Helm conventions where possible.

Standard deployment:

```text
make helm-deploy
```

Observability-aware deployment:

```text
make helm-deploy-observability
```

The GitHub workflow should use the observability-aware deployment only when Prometheus Operator CRDs are installed.

## Image tagging strategy

The workflow should build and push at least one immutable tag:

```text
commit SHA
```

Example:

```text
incident-api:<github-sha>
```

Optionally, it can also push:

```text
incident-api:0.1.0
incident-api:latest
```

Recommendation for V3:

```text
use commit SHA as the deployment tag
avoid relying on latest for reproducibility
```

## Post-deployment validation

After Helm deployment, the workflow should validate the application.

Expected checks:

```text
kubectl rollout status deployment/incident-api-incident-api -n incident-api
kubectl get pods -n incident-api
kubectl get svc -n incident-api
kubectl port-forward or in-cluster check for /health
kubectl port-forward or in-cluster check for /ready
```

Because GitHub-hosted runners cannot easily keep long-lived port-forwards, V3 may use a temporary Kubernetes run pod for in-cluster HTTP checks.

Example validation concept:

```text
kubectl run curl-check --rm -i --restart=Never --image=curlimages/curl -- \
  curl -f http://incident-api-incident-api.incident-api.svc.cluster.local/health
```

## Out of scope for V3

V3 will not include:

```text
automatic terraform apply on push
automatic terraform destroy
public ingress
LoadBalancer service
TLS termination
blue/green deployment
canary deployment
Argo CD or Flux
```

These are later iterations.

## Risks and mitigations

### Risk: accidental cloud cost

Mitigation:

```text
manual workflow_dispatch only
no terraform apply in deployment workflow
no push-based deployment
explicit documentation that EKS must be created manually
```

### Risk: deploy workflow runs when EKS is destroyed

Mitigation:

```text
first step checks aws eks describe-cluster
fail fast if cluster does not exist
clear error message for the operator
```

### Risk: overly broad deployment permissions

Mitigation:

```text
separate deploy role
trust policy scoped to repository and branch
least-privilege AWS IAM policy
namespace-scoped Kubernetes Role and RoleBinding
no cluster-wide admin policy for deployment
```

## V3 deliverables

V3 should produce:

```text
docs/deployment-v3-design.md
GitHub Environment dev
Terraform IAM role for GitHub Actions deploy
least-privilege AWS IAM policy for deploy role
EKS access entry for deploy role
versioned Kubernetes RBAC manifest for deploy role
manual GitHub Actions deployment workflow
post-deployment health checks
README update
architecture update
release-v3.md
v3.0.0 Git tag
```

## Decision summary

V3 will add manual, controlled application deployment automation through GitHub Actions.

It will not provision EKS automatically.

The operator remains responsible for explicitly creating and destroying AWS infrastructure with Makefile commands.

The deployment workflow only deploys the application to an existing EKS cluster, using GitHub OIDC, a dedicated least-privilege deploy role, versioned namespace-scoped Kubernetes RBAC, Helm, and post-deployment health checks.