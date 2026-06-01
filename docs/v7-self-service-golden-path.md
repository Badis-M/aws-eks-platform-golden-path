

# V7 Self-Service Golden Path

V7 turns the AWS EKS Platform Golden Path into a reusable platform model.

The goal is to define how a new service can be onboarded using the same
conventions as the Incident API: containerization, Helm deployment,
observability, alerting, CI/CD, RBAC, release strategy, and runbooks.

## Platform goal

The platform provides a paved road for application teams.

It should make the recommended path easy to follow:

```text
code
-> tests
-> container image
-> Helm chart
-> CI validation
-> manual deployment
-> observability
-> alerting
-> rollback
-> runbook
```

The platform does not try to hide Kubernetes or AWS completely. It provides a
clear, secure, and repeatable operating model.

## Golden path contract

A service is compatible with the platform when it follows the golden path
contract.

The contract includes:

- application endpoint conventions
- Docker image conventions
- Kubernetes label conventions
- Helm values conventions
- observability conventions
- alerting conventions
- CI validation requirements
- manual deployment expectations
- rollback expectations
- operational runbook requirements

## Application team responsibilities

Application teams own:

- service source code
- application tests
- Dockerfile
- runtime dependencies
- health endpoint
- readiness endpoint
- metrics endpoint
- application metrics
- service-specific alerts
- service-specific runbooks

Required endpoints:

```text
/health
/ready
/metrics
```

Application teams must avoid:

- secrets hardcoded in code
- secrets baked into images
- unbounded resource usage
- undocumented operational behavior
- public exposure by default

## Platform team responsibilities

The platform team owns:

- Terraform infrastructure modules
- EKS cluster lifecycle
- ECR repository model
- GitHub OIDC integration
- IAM role design
- Kubernetes RBAC patterns
- Helm chart conventions
- CI/CD workflow patterns
- observability stack installation
- platform documentation
- cost-aware cleanup procedures

The platform team should make the secure path the default path.

## Service onboarding flow

A new service should follow this onboarding process.

```text
1. Define service metadata
2. Implement required operational endpoints
3. Add Dockerfile
4. Add or reuse Helm chart conventions
5. Add CI validation
6. Add observability configuration
7. Add alerting configuration if needed
8. Add deployment workflow configuration
9. Add rollback procedure
10. Add runbook
11. Validate on EKS
12. Document release notes
```

The detailed checklist is available in:

```text
docs/onboarding/new-service-checklist.md
```

## Naming conventions

Recommended naming model:

```text
service name: <service-name>
namespace: <service-name>
Helm release: <service-name>
container name: <service-name>
Kubernetes Service: <service-name>
Kubernetes Deployment: <service-name>
```

Helm charts should support:

```text
nameOverride
fullnameOverride
```

This keeps resource names predictable for:

- rollout checks
- smoke tests
- Prometheus queries
- runbooks
- troubleshooting

## Deployment model

Deployments remain manual and controlled.

Expected flow:

```text
workflow_dispatch
-> GitHub Environment approval
-> GitHub OIDC authentication
-> image build and push
-> Helm upgrade
-> rollout status
-> smoke test
```

Deployment workflows should not create or destroy cloud infrastructure.

Infrastructure lifecycle remains explicit:

```text
make tf-apply
make tf-destroy
```

## Observability model

Observability is optional at chart-rendering time but expected for real
platform validation.

Default chart behavior:

```text
serviceMonitor.enabled=false
alerting.enabled=false
```

Observability mode can enable:

```text
serviceMonitor.enabled=true
alerting.enabled=true
```

This avoids rendering Prometheus Operator custom resources when the CRDs are
not installed.

## Alerting model

Alerting should remain actionable.

Baseline alert categories:

- service down
- metrics missing
- high restart count
- high 5xx rate

Each alert should have:

- clear name
- severity label
- summary annotation
- description annotation
- runbook or recovery steps

## RBAC model

Runtime deployment permissions should be namespace-scoped where possible.

A deploy workflow should only manage resources required by the service.

Typical namespace-scoped resources:

- Deployments
- Services
- Pods for smoke tests
- ServiceMonitors
- PrometheusRules

The deploy workflow should not require cluster-admin permissions.

## Release model

Each service should support:

- visible image tags
- Helm release history
- manual deployment
- rollback workflow or rollback runbook
- post-deploy smoke test

Rollback should be based on Helm revisions when possible.

```bash
helm history <release-name> -n <namespace>
helm rollback <release-name> <revision> -n <namespace>
```

## Cost-aware model

Services must remain compatible with the platform cost-control strategy.

Default assumptions:

- no public LoadBalancer by default
- no public Grafana endpoint by default
- no public Prometheus endpoint by default
- no automatic EKS creation from deployment workflows
- no uncontrolled always-on expensive resources
- cleanup must be documented

## Validation gates

Before a service is considered onboarded, these gates should pass:

- application tests pass
- Docker image builds
- Helm lint passes
- Helm standard rendering passes
- Helm observability rendering passes
- Platform CI is green
- manual deploy workflow succeeds
- rollout check succeeds
- smoke test succeeds
- Prometheus scrape works when observability is enabled
- alert rules load when alerting is enabled
- rollback path is documented or automated

## Current reference implementation

The Incident API is the current reference implementation.

It demonstrates:

- FastAPI service
- Docker image build
- ECR image push
- Helm deployment
- ServiceMonitor integration
- PrometheusRule alerting
- GitHub Actions deployment
- GitHub Environment approval
- namespace-scoped RBAC
- Helm rollback workflow
- operational runbook

## Out of scope

V7 does not create a second production microservice.

It defines the reusable platform contract and onboarding process first.

Future work can add:

- service template repository
- reusable Helm starter chart
- second example service
- automated service scaffolding
- policy-as-code checks for service onboarding

## Final V7 outcome

V7 defines the platform as a reusable golden path instead of a one-off
application deployment.

The platform now has:

```text
reference implementation
-> onboarding checklist
-> service contract
-> deployment model
-> observability model
-> alerting model
-> rollback model
-> cost-aware operating boundaries
```