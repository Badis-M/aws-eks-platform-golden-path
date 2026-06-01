# Incident API Alerts Runbook

This runbook explains how to investigate and recover from Incident API alerts.

The alerts are managed through the Helm chart and rendered as a
`PrometheusRule` when observability mode is enabled.

## Scope

Namespace:

```text
incident-api
```

Helm release:

```text
incident-api
```

Main Kubernetes resources:

```text
deployment/incident-api
service/incident-api
servicemonitor/incident-api
prometheusrule/incident-api
```

## Alert list

The Incident API currently defines four alerts.

| Alert | Severity | Purpose |
| --- | --- | --- |
| `IncidentAPIDown` | critical | Prometheus cannot scrape the application target |
| `IncidentAPIMetricsMissing` | warning | The application info metric is missing |
| `IncidentAPIHighRestartCount` | warning | The container restarted recently |
| `IncidentAPIHigh5xxRate` | critical | The API is returning HTTP 5xx responses |

## Initial checks

Start with the cluster state.

```bash
kubectl get pods -n incident-api
kubectl get deploy,svc,servicemonitor,prometheusrule -n incident-api
kubectl describe deployment incident-api -n incident-api
```

Check the application logs.

```bash
kubectl logs deployment/incident-api -n incident-api
```

Check the application endpoints from inside the cluster.

```bash
kubectl run incident-api-debug \
  --namespace incident-api \
  --rm \
  --restart=Never \
  --image=curlimages/curl:8.10.1 \
  --command -- sh -c "
    curl --fail --silent http://incident-api.incident-api.svc.cluster.local/health &&
    echo &&
    curl --fail --silent http://incident-api.incident-api.svc.cluster.local/ready &&
    echo &&
    curl --fail --silent http://incident-api.incident-api.svc.cluster.local/metrics
  "
```

If `--rm` is not suitable for the current shell or CI context, create a
temporary pod, inspect logs, then delete it explicitly.

## Prometheus and Grafana checks

Open Grafana locally.

```bash
kubectl port-forward -n observability svc/observability-grafana 3000:80
```

In Grafana Explore, select the Prometheus datasource and run:

```promql
ALERTS{alertname=~"IncidentAPI.*"}
```

Check whether Prometheus can scrape the application.

```promql
up{namespace="incident-api", service="incident-api"}
```

Check whether application metrics are present.

```promql
incident_api_info{namespace="incident-api"}
```

Check request rates and errors.

```promql
sum by (path) (
  rate(http_requests_total{namespace="incident-api"}[5m])
)
```

```promql
sum(rate(http_requests_total{namespace="incident-api", status=~"5.."}[5m]))
```

## IncidentAPIDown

### IncidentAPIDown meaning

Prometheus cannot scrape the Incident API target.

The alert expression is:

```promql
up{namespace="incident-api", service="incident-api"} == 0
```

### IncidentAPIDown common causes

- application pod is down
- readiness probe is failing
- Service selector does not match pod labels
- ServiceMonitor selector does not match the Service labels
- Prometheus cannot reach the target

### IncidentAPIDown diagnosis

```bash
kubectl get pods -n incident-api
kubectl describe pod -n incident-api -l app.kubernetes.io/name=incident-api
kubectl get svc incident-api -n incident-api -o yaml
kubectl get servicemonitor incident-api -n incident-api -o yaml
```

Check the scrape status in Prometheus or Grafana:

```promql
up{namespace="incident-api", service="incident-api"}
```

### IncidentAPIDown recovery

If the Deployment is not healthy, restart it.

```bash
kubectl rollout restart deployment/incident-api -n incident-api
kubectl rollout status deployment/incident-api -n incident-api --timeout=180s
```

If the Deployment was scaled down, restore one replica.

```bash
kubectl scale deployment incident-api -n incident-api --replicas=1
```

## IncidentAPIMetricsMissing

### IncidentAPIMetricsMissing meaning

Prometheus does not see the `incident_api_info` metric.

The alert expression is:

```promql
absent(incident_api_info{namespace="incident-api"})
```

### IncidentAPIMetricsMissing common causes

- `/metrics` endpoint is broken
- ServiceMonitor is missing
- Prometheus has not discovered the target
- the application changed its metric names

### IncidentAPIMetricsMissing diagnosis

Check the metric directly from inside the cluster.

```bash
kubectl run incident-api-metrics-check \
  --namespace incident-api \
  --rm \
  --restart=Never \
  --image=curlimages/curl:8.10.1 \
  --command -- sh -c "
    curl --fail --silent http://incident-api.incident-api.svc.cluster.local/metrics |
    grep incident_api_info
  "
```

Check the ServiceMonitor.

```bash
kubectl get servicemonitor incident-api -n incident-api -o yaml
```

Check Prometheus discovery.

```promql
up{namespace="incident-api", service="incident-api"}
```

### IncidentAPIMetricsMissing recovery

If the ServiceMonitor is missing, redeploy the app with observability mode
enabled.

```text
GitHub Actions -> Deploy Incident API -> enable_observability=true
```

If the metric is missing from the application, inspect the application code and
redeploy a fixed image.

## IncidentAPIHighRestartCount

### IncidentAPIHighRestartCount meaning

The Incident API container restarted recently.

The alert expression is:

```promql
increase(kube_pod_container_status_restarts_total{namespace="incident-api", container="incident-api"}[5m]) > 0
```

### IncidentAPIHighRestartCount common causes

- application crash
- failed liveness probe
- memory limit exceeded
- image or dependency issue
- startup failure after deployment

### IncidentAPIHighRestartCount diagnosis

```bash
kubectl get pods -n incident-api
kubectl describe pod -n incident-api -l app.kubernetes.io/name=incident-api
kubectl logs deployment/incident-api -n incident-api
kubectl logs deployment/incident-api -n incident-api --previous
```

Check resource usage if metrics are available.

```bash
kubectl top pods -n incident-api
```

### IncidentAPIHighRestartCount recovery

If the current image is unhealthy, rollback the Helm release.

```bash
helm history incident-api -n incident-api
helm rollback incident-api <REVISION> -n incident-api
kubectl rollout status deployment/incident-api -n incident-api --timeout=180s
```

If the issue is transient, restart the Deployment.

```bash
kubectl rollout restart deployment/incident-api -n incident-api
```

## IncidentAPIHigh5xxRate

### IncidentAPIHigh5xxRate meaning

The Incident API is returning HTTP 5xx responses.

The alert expression is:

```promql
sum(rate(http_requests_total{namespace="incident-api", status=~"5.."}[5m])) > 0
```

### IncidentAPIHigh5xxRate common causes

- unhandled application exception
- downstream dependency failure
- configuration issue
- bad release

### IncidentAPIHigh5xxRate diagnosis

Check 5xx rate.

```promql
sum by (path, status) (
  rate(http_requests_total{namespace="incident-api", status=~"5.."}[5m])
)
```

Check application logs.

```bash
kubectl logs deployment/incident-api -n incident-api
```

Check rollout history.

```bash
helm history incident-api -n incident-api
kubectl rollout history deployment/incident-api -n incident-api
```

### IncidentAPIHigh5xxRate recovery

If the issue started after a release, rollback.

```bash
helm history incident-api -n incident-api
helm rollback incident-api <REVISION> -n incident-api
kubectl rollout status deployment/incident-api -n incident-api --timeout=180s
```

If the issue is caused by code or configuration, build and deploy a fixed
image through the manual deployment workflow.

## Post-recovery checks

After any recovery action, validate Kubernetes health.

```bash
kubectl get pods -n incident-api
kubectl rollout status deployment/incident-api -n incident-api --timeout=180s
```

Validate application endpoints.

```bash
kubectl run incident-api-smoke-check \
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

Validate Prometheus state.

```promql
up{namespace="incident-api", service="incident-api"}
```

```promql
ALERTS{alertname=~"IncidentAPI.*", alertstate="firing"}
```

Expected result after recovery:

```text
no firing Incident API alerts
```

## Notes

This runbook assumes that the observability stack is installed and that the
deployment was performed with:

```text
enable_observability=true
```

Alert routing through Alertmanager is not configured yet. In the current V5
scope, alerts are validated through Prometheus and Grafana queries.