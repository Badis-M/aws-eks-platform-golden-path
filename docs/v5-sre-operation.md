# V5 SRE Operations

V5 adds an SRE-oriented layer to the AWS EKS Platform Golden Path.

The goal is to move from observability to operational readiness by adding
alert rules, validation steps, an incident simulation, and a runbook.

## Scope

V5 focuses on the Incident API and its Kubernetes observability path.

Implemented scope:

- Helm-managed `PrometheusRule`
- alerting disabled by default
- alerting enabled through observability values
- Platform CI validation for alert rule rendering
- namespace-scoped RBAC update for `prometheusrules`
- EKS validation with Prometheus Operator
- Prometheus query validation
- controlled incident simulation
- recovery validation
- operational runbook

## Alerting model

Alert rules are managed by the Incident API Helm chart.

The default chart values keep alerting disabled:

```text
alerting.enabled=false
```

Observability mode enables alerting through:

```text
observability/incident-api-observability-values.yaml
```

This ensures that `PrometheusRule` resources are created only when the
Prometheus Operator CRDs are installed.

## Alert rules

V5 defines four application alerts.

| Alert | Severity | Purpose |
| --- | --- | --- |
| `IncidentAPIDown` | critical | Prometheus cannot scrape the API target |
| `IncidentAPIMetricsMissing` | warning | The application info metric is missing |
| `IncidentAPIHighRestartCount` | warning | The container restarted recently |
| `IncidentAPIHigh5xxRate` | critical | The API is returning HTTP 5xx responses |

## Helm validation

Standard mode must not render a `PrometheusRule`:

```bash
helm template incident-api helm/incident-api \
  --namespace incident-api \
  --set fullnameOverride=incident-api | grep "kind: PrometheusRule" || true
```

Observability mode must render the `PrometheusRule` and all expected alerts:

```bash
helm template incident-api helm/incident-api \
  --namespace incident-api \
  --set fullnameOverride=incident-api \
  --values observability/incident-api-observability-values.yaml \
  | grep -E "kind: PrometheusRule|IncidentAPIDown|IncidentAPIHigh5xxRate"
```

The Makefile target also validates alerting rendering:

```bash
make helm-alerting-validate
make helm-validate
make observability-check
```

## CI validation

Platform CI validates PrometheusRule rendering without requiring a live EKS
cluster.

The CI validates that:

- no `PrometheusRule` is rendered by default
- observability values render a `PrometheusRule`
- all four alert names are present
- existing ServiceMonitor rendering checks still pass
- `fullnameOverride=incident-api` is used consistently

## Kubernetes RBAC update

The GitHub Actions deploy role must manage application alert rules in the
`incident-api` namespace.

The namespace-scoped Kubernetes Role was updated to include:

```text
prometheusrules.monitoring.coreos.com
```

This permission remains namespace-scoped and does not grant cluster-admin
privileges.

## EKS validation

The platform was recreated temporarily for V5 validation.

Required setup:

```bash
make tf-apply
make kubeconfig
kubectl apply -f kubernetes/rbac/github-actions-deploy.yaml
kubectl apply -f kubernetes/networkpolicies/incident-api.yaml
make observability-install
```

The application was deployed through the manual GitHub Actions workflow with:

```text
enable_observability=true
```

After deployment, the PrometheusRule was validated in the cluster:

```bash
kubectl get prometheusrule -n incident-api
kubectl describe prometheusrule incident-api -n incident-api
```

The Prometheus Operator accepted the rule with:

```text
prometheus-operator-validated: true
```

## Prometheus validation

Prometheus was accessed directly through port-forwarding:

```bash
kubectl port-forward -n observability svc/observability-prometheus 9090:9090
```

The following checks were validated:

```promql
ALERTS{alertname=~"IncidentAPI.*"}
```

```promql
up{namespace="incident-api", service="incident-api"}
```

The expected healthy state is:

```text
up = 1
no firing IncidentAPI alerts
```

## Controlled incident simulation

The `IncidentAPIDown` path was tested by scaling the application down to zero.

Incident trigger:

```bash
kubectl scale deployment incident-api \
  --namespace incident-api \
  --replicas=0
```

Validation:

```bash
kubectl get pods -n incident-api
```

Expected result during the incident:

```text
No resources found in incident-api namespace.
```

Recovery:

```bash
kubectl scale deployment incident-api \
  --namespace incident-api \
  --replicas=1

kubectl rollout status deployment/incident-api \
  --namespace incident-api \
  --timeout=180s
```

Expected recovery result:

```text
deployment "incident-api" successfully rolled out
```

## Runbook

The operational runbook is available in:

```text
docs/runbooks/incident-api-alerts.md
```

It documents:

- alert meaning
- common causes
- diagnostic commands
- recovery commands
- post-recovery checks

## Current limitations

V5 does not configure external alert routing yet.

Out of scope for this release:

- Alertmanager routing
- Slack notifications
- email notifications
- Grafana dashboard as code
- long-term incident history

These can be added in later SRE iterations.

## Final V5 outcome

V5 validates the following operational path:

```text
application metrics
-> ServiceMonitor
-> Prometheus scrape
-> PrometheusRule alerting
-> Prometheus query validation
-> controlled incident simulation
-> recovery validation
-> documented runbook
```

