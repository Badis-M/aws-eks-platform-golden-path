

# New Service Onboarding Checklist

This checklist defines the minimum requirements for onboarding a new service
into the AWS EKS Platform Golden Path.

The goal is to make service onboarding repeatable, predictable, observable,
and safe to operate.

## 1. Service basics

Each service must define:

- service name
- owning team
- runtime language
- container image name
- Kubernetes namespace
- Helm release name
- expected exposed port
- health endpoint
- readiness endpoint
- metrics endpoint

Recommended naming convention:

```text
service name: <service-name>
namespace: <service-name>
helm release: <service-name>
container name: <service-name>
```

## 2. Application requirements

The application must expose operational endpoints.

Required endpoints:

```text
/health
/ready
/metrics
```

Endpoint purpose:

| Endpoint | Purpose |
| --- | --- |
| `/health` | confirms that the process is alive |
| `/ready` | confirms that the app can receive traffic |
| `/metrics` | exposes Prometheus-compatible metrics |

## 3. Metrics requirements

The service should expose Prometheus metrics.

Minimum recommended metrics:

- application info metric
- HTTP request counter
- HTTP request duration histogram if relevant
- status-code labels
- path or route labels
- method labels

Example metric naming pattern:

```text
<service_name>_info
http_requests_total
http_request_duration_seconds
```

## 4. Docker requirements

The service image must follow baseline container standards.

Required:

- Dockerfile stored with the service source code
- non-root runtime user
- explicit exposed application port
- minimal runtime image where possible
- no secrets baked into the image
- deterministic dependency installation
- local build command documented

Recommended validation:

```bash
docker build -t <service-name>:local <service-path>
docker run --rm -p 8000:8000 <service-name>:local
```

## 5. Kubernetes requirements

Each service must provide or inherit Kubernetes definitions for:

- Deployment
- Service
- resource requests and limits
- readiness probe
- liveness probe
- labels compatible with Helm selectors

Recommended labels:

```text
app.kubernetes.io/name
app.kubernetes.io/instance
app.kubernetes.io/version
app.kubernetes.io/managed-by
```

## 6. Helm requirements

Each service should be deployed through Helm.

The chart must support:

```text
nameOverride
fullnameOverride
image.repository
image.tag
service.port
service.targetPort
resources.requests
resources.limits
serviceMonitor.enabled
alerting.enabled
```

Default behavior:

```text
serviceMonitor.enabled=false
alerting.enabled=false
```

Observability mode can enable both when the Prometheus Operator CRDs exist.

## 7. Observability requirements

A service is observability-ready when it provides:

- Prometheus metrics endpoint
- Prometheus scrape annotations or ServiceMonitor
- optional PrometheusRule alerts
- Grafana or Prometheus validation queries
- documented troubleshooting commands

Recommended PromQL checks:

```promql
up{namespace="<service-namespace>", service="<service-name>"}
```

```promql
rate(http_requests_total{namespace="<service-namespace>"}[5m])
```

## 8. Alerting requirements

If alerting is enabled, the service should define a small number of actionable
alerts.

Recommended baseline alerts:

- service down
- metrics missing
- high restart count
- high 5xx rate

Alert rules must avoid unnecessary noise.

Each alert must have:

- clear name
- severity label
- summary annotation
- description annotation
- documented runbook or recovery steps

## 9. CI requirements

Each service should be validated by CI before deployment.

Minimum checks:

- unit tests
- linting if applicable
- Docker build
- Helm lint
- Helm template rendering
- observability rendering checks when relevant
- YAML validation for Kubernetes manifests

CI must not require a live EKS cluster for basic validation.

## 10. Deployment requirements

Service deployment should remain controlled.

Expected deployment model:

```text
manual workflow_dispatch
-> GitHub Environment approval
-> GitHub OIDC authentication
-> image build and push
-> Helm upgrade
-> rollout validation
-> smoke test
```

Deployment workflows should not create or destroy cloud infrastructure.

## 11. RBAC requirements

Deployment permissions should be namespace-scoped where possible.

The deploy role should be able to manage only the resources required by the
service, such as:

- Deployments
- Services
- Pods for smoke tests
- ServiceMonitors when observability is enabled
- PrometheusRules when alerting is enabled

The deploy role should not be cluster-admin.

## 12. Release requirements

Each service should support safe release operations.

Required:

- image tag visible in Helm values
- Helm release history available
- rollback workflow or rollback procedure
- post-deploy smoke test
- release note for significant platform changes

Recommended rollback command:

```bash
helm rollback <release-name> <revision> -n <namespace>
```

## 13. Runbook requirements

Each service should provide basic operational documentation.

Required runbook sections:

- symptoms
- impact
- initial checks
- logs
- metrics
- common causes
- recovery commands
- post-recovery checks

## 14. Cost and cleanup requirements

Services must remain compatible with the platform cost-aware model.

Required:

- no public LoadBalancer unless explicitly approved
- no uncontrolled always-on expensive resource
- cleanup documented
- cloud resources created intentionally through Terraform
- application deployment separated from infrastructure lifecycle

## 15. Onboarding validation checklist

Before a service is considered onboarded, validate:

- application tests pass
- Docker image builds locally
- Helm chart renders locally
- standard Helm mode works without observability CRDs
- observability Helm mode works when CRDs are installed
- CI is green
- deployment workflow succeeds
- rollout status succeeds
- smoke test succeeds
- metrics are visible in Prometheus
- alert rules are loaded if enabled
- rollback procedure is documented or automated
- cleanup path is documented

## Final onboarding outcome

A service is onboarded when it can follow this path:

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