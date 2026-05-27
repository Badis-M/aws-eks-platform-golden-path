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
