

# Observability V2 Design

## Purpose

V2 extends the platform from application-level metrics readiness to a real Kubernetes observability stack running on Amazon EKS.

V1 already provides:

```text
FastAPI /metrics endpoint
prometheus-client metrics
Helm Prometheus scrape annotations
Platform CI validation for observability annotations
Makefile observability checks
```

V2 will add:

```text
Prometheus deployed on EKS
Grafana deployed on EKS
Prometheus scraping the Incident API /metrics endpoint
Grafana dashboard for application metrics
Observability runbook and cleanup workflow
```

## Target architecture

```text
Amazon EKS
  |
  ├── incident-api namespace
  │     |
  │     ├── Incident API Deployment
  │     ├── ClusterIP Service
  │     └── /metrics endpoint
  │
  └── observability namespace
        |
        ├── Prometheus
        ├── Grafana
        ├── kube-state-metrics
        ├── node-exporter
        └── Prometheus Operator
```

Prometheus will collect metrics from:

```text
Incident API /metrics
Kubernetes nodes
Kubernetes objects
Prometheus itself
```

Grafana will visualize the collected metrics through port-forward access.

## Helm chart choice

V2 will use:

```text
prometheus-community/kube-prometheus-stack
```

Reason:

```text
standard Kubernetes observability stack
includes Prometheus and Grafana
includes kube-state-metrics and node-exporter
uses Prometheus Operator
supports ServiceMonitor resources
widely used in SRE and platform engineering environments
```

Alternative rejected for V2:

```text
prometheus-community/prometheus + standalone Grafana
```

Reason for rejection:

```text
more manual wiring
less representative of modern Kubernetes observability practices
less useful for later ServiceMonitor-based workflows
```

## Namespace strategy

V2 will use a dedicated namespace:

```text
observability
```

The application remains deployed separately:

```text
incident-api
```

This keeps platform tooling separate from application workloads.

Expected layout:

```text
incident-api namespace
→ application runtime

observability namespace
→ Prometheus, Grafana, exporters, operator
```

## Metrics discovery strategy

The current Incident API Helm chart exposes Prometheus annotations:

```yaml
prometheus.io/scrape: "true"
prometheus.io/path: "/metrics"
prometheus.io/port: "8000"
```

For V2, the preferred long-term approach is to add a `ServiceMonitor`.

Reason:

```text
ServiceMonitor is the native discovery mechanism used by Prometheus Operator.
It is cleaner than relying only on pod annotations when using kube-prometheus-stack.
```

V2 can be implemented in two steps:

```text
Step 1: deploy kube-prometheus-stack and validate the stack
Step 2: add ServiceMonitor support to the Incident API Helm chart
```

## ServiceMonitor design

The Incident API Helm chart should expose an optional ServiceMonitor configuration:

```yaml
serviceMonitor:
  enabled: true
  interval: 15s
  path: /metrics
  labels:
    release: observability
```

Expected ServiceMonitor behavior:

```text
select the Incident API Service
scrape the http port
use /metrics as the scrape path
run in the same namespace as the application or a controlled namespace strategy
match Prometheus Operator selector labels
```

This should remain optional so the chart can still render and deploy without Prometheus installed.

## Access strategy

No public endpoint will be created in V2.

Access will use port-forward only:

```bash
kubectl port-forward -n observability svc/observability-grafana 3000:80
kubectl port-forward -n observability svc/observability-kube-prometheus-prometheus 9090:9090
```

Reason:

```text
no LoadBalancer cost
no public exposure
no DNS requirement
no HTTPS setup required for V2
```

## Validation plan

### 1. Infrastructure validation

```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

Expected result:

```text
EKS cluster created
managed node group ready
kubeconfig updated
nodes visible with kubectl
```

### 2. Application validation

```bash
make ecr-build-push
make helm-deploy
kubectl get pods -A
```

Expected result:

```text
Incident API pod running
Service created
/health works through port-forward
/ready works through port-forward
/metrics works through port-forward
```

### 3. Observability stack validation

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install observability prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace
```

Expected result:

```text
Prometheus pods running
Grafana pod running
kube-state-metrics running
node-exporter running
```

### 4. Metrics scrape validation

Prometheus should show the Incident API target as active.

Validation options:

```text
Prometheus UI targets page
Prometheus query UI
Grafana dashboard panel
```

Useful PromQL queries:

```text
incident_api_info
http_requests_total
rate(http_requests_total[5m])
```

### 5. Grafana validation

Port-forward Grafana:

```bash
kubectl port-forward -n observability svc/observability-grafana 3000:80
```

Then validate:

```text
Grafana login works
Prometheus datasource exists
Incident API metrics can be queried
basic dashboard can display request counters
```

## Cost controls

V2 still follows the ephemeral lab model.

Cost controls:

```text
EKS is temporary
no NAT Gateway
no LoadBalancer
no public ingress
minimal node group size
Grafana and Prometheus accessed by port-forward
terraform destroy after validation
```

The observability stack adds pods and resource consumption, so V2 should be tested in short sessions.

## Security decisions

V2 security decisions:

```text
no public Grafana endpoint
no public Prometheus endpoint
port-forward access only
no Grafana credentials committed
no static AWS credentials
OIDC remains the AWS authentication model for GitHub Actions
observability namespace isolates platform tooling from the application namespace
```

Grafana admin credentials should be handled through Kubernetes secrets generated by the Helm chart or explicitly set through non-committed values.

## Destroy plan

Destroy order should be explicit.

Recommended order:

```bash
helm uninstall observability -n observability
kubectl delete namespace observability
make helm-uninstall
cd terraform/environments/dev
terraform destroy
```

If testing only observability changes, uninstall the observability stack before destroying EKS.

The S3 backend remains separate and should usually remain available.

## Known risks and trade-offs

### kube-prometheus-stack complexity

The chart is large and realistic, but it introduces many Kubernetes objects.

Mitigation:

```text
use a dedicated namespace
start with default values
avoid custom dashboards until the stack is stable
```

### Resource pressure on small nodes

Prometheus, Grafana, exporters, and the application may be heavy for a minimal node group.

Mitigation:

```text
keep replica counts low
use small retention settings
increase node size only if required
monitor pod scheduling failures
```

### ServiceMonitor label matching

Prometheus Operator may not discover a ServiceMonitor if labels or selectors do not match.

Mitigation:

```text
inspect Prometheus serviceMonitorSelector behavior
use labels expected by the Helm release
validate targets in Prometheus UI
```

### Ephemeral environment

Destroying the dev environment removes EKS and all observability workloads.

Mitigation:

```text
document install and validation commands
keep observability values versioned
keep dashboards exportable
```

## V2 deliverables

V2 should produce:

```text
observability Helm values file
optional ServiceMonitor template for incident-api
Makefile observability stack commands
README update
architecture update
observability runbook
release-v2.md
v2.0.0 Git tag
```

## Out of scope for V2

V2 will not include:

```text
public Grafana URL
Ingress controller
TLS termination
production alerting rules
PagerDuty or Slack integration
long-term metrics storage
Loki logs stack
Tempo tracing stack
```

These are candidates for later versions.

## Decision summary

V2 will use `kube-prometheus-stack` deployed through Helm into a dedicated `observability` namespace.

The Incident API will remain in its own namespace and expose Prometheus metrics through `/metrics`.

The first V2 goal is to prove that Prometheus can scrape the application metrics and that Grafana can visualize them, without exposing observability tools publicly and without adding unnecessary AWS cost.