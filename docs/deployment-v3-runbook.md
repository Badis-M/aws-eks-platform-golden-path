# V3 Manual Deployment Runbook

This runbook explains how to deploy the Incident API manually to an
existing AWS EKS cluster.

V3 keeps infrastructure creation and application deployment intentionally separated:

- Terraform creates and destroys AWS infrastructure.
- GitHub Actions deploys the application only when manually triggered.
- The deploy workflow never runs `terraform apply` or `terraform destroy`.

## Deployment model

The V3 deployment flow is:

```text
Local operator
-> terraform apply
-> EKS cluster exists
-> Kubernetes RBAC bootstrap
-> manual GitHub Actions deployment
-> Helm deploys Incident API
-> post-deployment checks
-> cleanup
-> terraform destroy
```

This keeps the platform cost-aware and avoids creating cloud resources automatically on push.

## Prerequisites

Before triggering the manual deployment workflow, the following must already
be in place:

- AWS credentials configured locally for the operator.
- Terraform backend already bootstrapped.
- EKS infrastructure created intentionally with Terraform.
- GitHub OIDC deploy role created by Terraform.
- EKS access entry mapping the deploy role to the Kubernetes group
  `incident-api-deployers`.
- Namespace-scoped Kubernetes RBAC applied manually.
- GitHub Environment `dev` configured if approval is required.
- GitHub variable `AWS_GITHUB_ACTIONS_DEPLOY_ROLE_ARN` configured.

## Step 1 - Create the infrastructure intentionally

From the project root, run:

```bash
make tf-apply
```

This creates the AWS infrastructure, including:

- VPC networking
- ECR repository
- EKS cluster
- IAM roles
- GitHub OIDC permissions
- EKS access entry for the deploy role

The deployment workflow must not create these resources.

## Step 2 - Configure local kubeconfig

Run:

```bash
make kubeconfig
```

Then verify access:

```bash
kubectl get nodes
```

Expected result:

```text
Kubernetes nodes are visible.
```

## Step 3 - Bootstrap Kubernetes RBAC

Apply the namespace-scoped RBAC manifest:

```bash
kubectl apply -f kubernetes/rbac/github-actions-deploy.yaml
```

This creates:

- `incident-api` namespace
- `incident-api-deployer` Role
- `incident-api-deployer` RoleBinding

The RoleBinding grants permissions to the Kubernetes group:

```text
incident-api-deployers
```

This group must match the EKS access entry managed by Terraform.

## Step 4 - Trigger the manual deployment workflow

In GitHub:

```text
Actions
-> Deploy Incident API
-> Run workflow
```

Select the target branch, then choose the observability mode.

## Step 5 - Choose observability mode

The workflow input is:

```text
enable_observability
```

Use:

```text
false
```

for a standard application deployment without `ServiceMonitor`.

Use:

```text
true
```

when `kube-prometheus-stack` and the Prometheus Operator CRDs are already installed.

When observability is enabled, the workflow includes:

```text
observability/incident-api-observability-values.yaml
```

This enables the `ServiceMonitor` used by Prometheus scraping.

## Step 6 - What the workflow does

The workflow performs the following actions:

- checks out the repository
- authenticates to AWS through GitHub OIDC
- validates the AWS caller identity
- fails fast if the EKS cluster does not exist
- logs in to Amazon ECR
- builds the Incident API Docker image
- pushes the image to ECR using the commit SHA as the tag
- updates kubeconfig for the existing EKS cluster
- deploys the application with Helm
- waits for the Kubernetes rollout
- lists deployed pods and services
- runs in-cluster `/health` and `/ready` checks

The workflow does not run:

- `terraform apply`
- `terraform destroy`
- `eks create-cluster`
- `eks delete-cluster`

## Step 7 - Validate the deployment manually

After the workflow succeeds, verify the application from your local terminal:

```bash
kubectl get pods,svc -n incident-api
```

Check the rollout:

```bash
kubectl rollout status deployment/incident-api \
  -n incident-api
```

Optional in-cluster health check:

```bash
kubectl run incident-api-manual-smoke-test \
  --namespace incident-api \
  --rm \
  --restart=Never \
  --image=curlimages/curl:8.10.1 \
  --command -- sh -c "
    curl --fail --silent http://incident-api.incident-api.svc.cluster.local/health &&
    echo &&
    curl --fail --silent http://incident-api.incident-api.svc.cluster.local/ready
  "
```

## Step 8 - Validate observability when enabled

If observability mode was enabled, verify the ServiceMonitor:

```bash
kubectl get servicemonitor -n incident-api
```

Expected result:

```text
incident-api ServiceMonitor is present.
```

Then port-forward Grafana if needed:

```bash
kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80
```

Validate these PromQL queries in Grafana Explore:

```promql
incident_api_info
```

```promql
http_requests_total
```

```promql
sum by (path) (
  rate(
    http_requests_total{
      namespace="incident-api",
      path=~"/health|/ready|/metrics"
    }[5m]
  )
)
```

## Step 9 - Cleanup application resources

Remove the application release:

```bash
make helm-uninstall
```

Remove the application namespace if needed:

```bash
kubectl delete namespace incident-api --ignore-not-found
```

If observability was installed for the validation session, remove it:

```bash
make observability-uninstall
```

Remove the observability namespace if needed:

```bash
kubectl delete namespace observability --ignore-not-found
```

## Step 10 - Destroy AWS infrastructure

Destroy the AWS infrastructure after the validation session:

```bash
make tf-destroy
```

Verify that the cluster no longer exists:

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

## Security notes

The deploy workflow uses a dedicated least-privilege IAM role.

It is allowed to:

- describe the EKS cluster
- authenticate to ECR
- push the Incident API image to ECR
- authenticate to Kubernetes through the EKS access entry
- deploy resources only where Kubernetes RBAC allows it

It is not allowed to:

- administer AWS globally
- create or delete EKS clusters
- modify IAM resources
- modify VPC resources
- manage cluster-wide Kubernetes resources
- deploy into arbitrary namespaces


## Real V3 validation issues and fixes

The first end-to-end V3 validation exposed several real-world integration
issues. These fixes are part of the platform learning path and document how
the manual deployment workflow became production-like.

### Missing GitHub Environment variable

Symptom:

```text
Credentials could not be loaded, please check your action inputs
```

Cause:

```text
The deploy workflow expected AWS_GITHUB_ACTIONS_DEPLOY_ROLE_ARN, but the
variable was not configured in the GitHub Environment named dev.
```

Fix:

```text
Add AWS_GITHUB_ACTIONS_DEPLOY_ROLE_ARN as a GitHub Environment variable under
Settings -> Environments -> dev.
```

Why this matters:

```text
The deploy role ARN is configuration, not a secret. The real security control
is the AWS OIDC trust policy combined with least-privilege IAM permissions.
```

### GitHub OIDC environment subject rejected

Symptom:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

Cause:

```text
The workflow used environment: dev, which changes the GitHub OIDC subject to
repo:<owner>/<repo>:environment:dev. The IAM trust policy only allowed the
main branch subject.
```

Fix:

```text
Update the IAM trust policy to allow both the main branch subject and the dev
environment subject.
```

Valid subjects:

```text
repo:<owner>/<repo>:ref:refs/heads/main
repo:<owner>/<repo>:environment:dev
```

Why this matters:

```text
GitHub Environments are useful for deployment approvals, but they must be
reflected in the AWS OIDC trust relationship.
```

### EKS admin access entry already exists

Symptom:

```text
ResourceInUseException: The specified access entry resource is already in use
```

Cause:

```text
AWS automatically created an EKS access entry for the cluster creator. The
Terraform module also tried to create the same admin access entry.
```

Fix:

```text
Stop managing aws_eks_access_entry.admin in Terraform and remove it from the
Terraform state with terraform state rm. Keep the admin access policy
association managed by Terraform.
```

Why this matters:

```text
Terraform should not try to create an access entry that AWS already created.
The GitHub deploy access entry remains Terraform-managed because it is a
separate least-privilege deployment identity.
```

### Helm namespace creation forbidden

Symptom:

```text
namespaces is forbidden
```

Cause:

```text
The Helm command used --create-namespace. Creating namespaces is a
cluster-scoped action, but the GitHub deploy role is intentionally restricted
to the incident-api namespace.
```

Fix:

```text
Remove --create-namespace from the deploy workflow. The namespace is created
during the manual RBAC bootstrap step.
```

Why this matters:

```text
Namespace creation remains an operator/bootstrap responsibility. The GitHub
deploy role only deploys inside an existing namespace.
```

### Deployment name mismatch

Symptom:

```text
deployments.apps "incident-api" not found
```

Cause:

```text
The Helm chart generated Kubernetes resources named incident-api-incident-api,
while the workflow checked for deployment/incident-api.
```

Fix:

```text
Add explicit workflow variables for the generated Kubernetes resource names:
K8S_DEPLOYMENT_NAME and K8S_SERVICE_NAME.
```

Why this matters:

```text
Post-deployment checks must validate the actual Kubernetes resources rendered
by Helm, not an assumed release name.
```

### kubectl run --rm not valid in GitHub Actions

Symptom:

```text
error: --rm should only be used for attached containers
```

Cause:

```text
kubectl run --rm expects an attached container session. This is not reliable
for a non-interactive GitHub Actions smoke test.
```

Fix:

```text
Create a temporary smoke test Pod, wait until it reaches Succeeded, read its
logs, then delete it explicitly.
```

Why this matters:

```text
CI/CD smoke tests should be deterministic and work in non-interactive runner
environments.
```

### Pod logs RBAC permission missing

Symptom:

```text
cannot get resource "pods/log" in API group "" in the namespace "incident-api"
```

Cause:

```text
Kubernetes treats pod logs as the pods/log subresource. The Role allowed pods
access but did not allow pods/log.
```

Fix:

```text
Add a namespace-scoped RBAC rule allowing get on pods/log.
```

Why this matters:

```text
Least-privilege RBAC often requires explicit subresources. Reading smoke test
logs is useful, but it should still be scoped to the application namespace.
```

### Final V3 validation result

The final successful workflow proves that GitHub Actions can:

- authenticate to AWS through OIDC
- assume the least-privilege deploy role
- verify that EKS already exists
- build the Incident API image
- push the image to ECR with the commit SHA tag
- update kubeconfig
- deploy with Helm
- wait for the Kubernetes rollout
- run an in-cluster smoke test
- clean up the temporary smoke test Pod

The workflow still does not run:

- `terraform apply`
- `terraform destroy`
- `eks create-cluster`
- `eks delete-cluster`

This confirms the V3 goal: controlled manual deployment automation without
automatic infrastructure creation.

## Troubleshooting

### EKS cluster not found

Symptom:

```text
ResourceNotFoundException
```

Cause:

```text
The workflow was triggered before the EKS cluster was created.
```

Fix:

```bash
make tf-apply
```

### Kubernetes forbidden error

Symptom:

```text
Error from server (Forbidden)
```

Cause:

```text
The GitHub deploy role authenticated successfully, but Kubernetes RBAC is
missing or incomplete.
```

Fix:

```bash
kubectl apply -f kubernetes/rbac/github-actions-deploy.yaml
```

### ServiceMonitor error

Symptom:

```text
no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
```

Cause:

```text
Observability mode was enabled but Prometheus Operator CRDs are not
installed.
```

Fix:

```text
Run the workflow again with `enable_observability=false`, or install
`kube-prometheus-stack` first.
```

## Interview explanation

```text
In this project, CI and CD are deliberately separated. CI validates the code
automatically, but cloud deployment is manual and protected. The deployment
workflow uses GitHub OIDC to assume a least-privilege AWS role, verifies that
the EKS cluster already exists, pushes a commit-tagged Docker image to ECR,
and deploys the application with Helm using namespace-scoped Kubernetes RBAC.
This avoids uncontrolled AWS costs and keeps the deployment path auditable and
secure.
```
