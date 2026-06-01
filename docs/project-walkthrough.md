

# Project Walkthrough

This document explains how the AWS EKS Platform Golden Path evolved from a
simple application deployment into a production-inspired platform engineering
project.

The goal is to describe the reasoning behind each version, not only the final
technical state.

## Project intent

The project demonstrates a senior DevOps, SRE, and Platform Engineering
workflow using AWS, Terraform, Kubernetes, Helm, GitHub Actions, observability,
security, FinOps, and operational documentation.

The platform is intentionally ephemeral and cost-aware.

The expected lifecycle is:

```text
create infrastructure
-> validate the platform capability
-> document the result
-> destroy infrastructure
-> verify cleanup
```

## High-level architecture

The platform connects the following components:

```text
Developer workstation
-> GitHub repository
-> GitHub Actions
-> GitHub OIDC
-> AWS IAM roles
-> Amazon ECR
-> Amazon EKS
-> Helm release
-> Incident API
-> Prometheus
-> Grafana
-> PrometheusRule alerts
```

Terraform owns the AWS infrastructure.

Helm owns the application deployment.

GitHub Actions owns CI, controlled deployment, rollback, and validation gates.

## V1 - Platform foundation

V1 established the core foundation.

The project started with a FastAPI Incident API exposing operational endpoints:

```text
/health
/ready
/metrics
```

The application was containerized with Docker and prepared for Kubernetes.

Terraform modules were added for:

- network
- EKS
- ECR
- IAM and GitHub OIDC

The first important principle was separation of responsibilities:

```text
Terraform provisions infrastructure
Helm deploys the application
GitHub Actions validates and automates workflows
```

V1 also introduced the cost-aware model.

EKS is treated as temporary infrastructure. The cluster is created for
validation sessions and destroyed afterward.

## V2 - Observability

V2 added Kubernetes observability.

The platform deployed `kube-prometheus-stack` on EKS and validated that
Prometheus and Grafana could observe the Incident API.

The application exposes Prometheus metrics on:

```text
/metrics
```

The Helm chart supports `ServiceMonitor` creation when observability mode is
enabled.

The important design decision was to keep observability custom resources
optional.

Default behavior:

```text
serviceMonitor.enabled=false
```

Observability mode:

```text
serviceMonitor.enabled=true
```

This allows the chart to render even when Prometheus Operator CRDs are not
installed.

V2 validated:

- Prometheus scraping
- ServiceMonitor discovery
- Grafana Explore
- application request metrics
- observability documentation

## V3 - Controlled manual deployment

V3 introduced controlled application deployment through GitHub Actions.

The goal was not to deploy automatically on every push. The goal was to build
a safe manual deployment workflow.

The deployment workflow uses:

```text
workflow_dispatch
-> GitHub OIDC
-> AWS deploy role
-> ECR image push
-> Helm upgrade
-> rollout status
-> in-cluster smoke test
```

The workflow validates that the EKS cluster already exists before deploying.

This is important because deployment automation must not create expensive AWS
infrastructure unexpectedly.

V3 also introduced commit-SHA image tagging.

This improves traceability:

```text
Git commit
-> Docker image tag
-> Helm deployment
```

## V4 - Production-grade hardening

V4 hardened the platform operating model.

The first hardening step was predictable Helm naming.

The chart supports:

```text
fullnameOverride=incident-api
```

This makes the Kubernetes resources predictable:

```text
deployment/incident-api
service/incident-api
servicemonitor/incident-api
prometheusrule/incident-api
```

Predictable names make rollout checks, smoke tests, Prometheus queries, and
runbooks simpler.

V4 also added GitHub Environment approval for the `dev` environment.

This created a controlled gate before deployment:

```text
manual workflow trigger
-> required reviewer approval
-> deployment execution
```

The Kubernetes deploy role was scoped to the `incident-api` namespace.

This avoids using cluster-admin for application deployment.

V4 also added NetworkPolicy validation to the platform checks.

## V5 - SRE alerting and incident operations

V5 moved the project from observability to SRE operations.

The Incident API chart gained optional `PrometheusRule` support.

Default behavior:

```text
alerting.enabled=false
```

Observability mode enables alerting when Prometheus Operator CRDs exist.

V5 added four alerts:

| Alert | Severity | Purpose |
| --- | --- | --- |
| `IncidentAPIDown` | critical | Prometheus cannot scrape the API target |
| `IncidentAPIMetricsMissing` | warning | The application info metric is missing |
| `IncidentAPIHighRestartCount` | warning | The container restarted recently |
| `IncidentAPIHigh5xxRate` | critical | The API is returning HTTP 5xx responses |

The alerting path was validated end to end:

```text
Helm template
-> Platform CI
-> GitHub deploy workflow
-> PrometheusRule in EKS
-> Prometheus Operator validation
-> Prometheus query validation
```

V5 also tested a controlled incident.

The Incident API deployment was scaled to zero, then restored to one replica.

This validated the basic SRE loop:

```text
incident trigger
-> detection path
-> recovery command
-> rollout validation
-> healthy Prometheus state
```

The result was documented in an alert runbook.

## V6 - Release and rollback strategy

V6 added controlled release operations.

The deployment workflow gained an optional input:

```text
image_tag
```

If the field is empty, the workflow uses the current commit SHA.

If the field is provided, the workflow uses the explicit tag value.

V6 also added a dedicated rollback workflow.

The rollback workflow does not build images and does not run Terraform.

It only performs release recovery:

```text
workflow_dispatch
-> GitHub Environment approval
-> helm history
-> helm rollback <revision>
-> rollout status
-> smoke test
```

The rollback was validated through Helm release history.

The important point is that rollback creates a new deployed revision while
restoring a previous release state.

## V7 - Self-service golden path

V7 transformed the project from a single application deployment into a
reusable platform model.

The Incident API became the reference implementation.

V7 documented what a new service must provide to be onboarded:

- health endpoint
- readiness endpoint
- metrics endpoint
- Dockerfile
- Helm values
- CI validation
- observability mode
- alerting mode
- rollback strategy
- runbook

The onboarding checklist defines the minimum service contract.

The self-service golden path is:

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

V7 is important because it shows platform thinking: the project is no longer
just about running one API. It defines how future services should use the
platform.

## V8 - FinOps and cleanup governance

V8 added explicit cost-control governance.

The project already followed an ephemeral model, but V8 made cleanup
verification repeatable.

A cleanup verification script was added:

```text
scripts/check-aws-cleanup.sh
```

It checks common AWS cost drivers after `terraform destroy`:

- EKS cluster
- LoadBalancers
- NAT Gateways
- EC2 instances
- unattached EBS volumes
- project Elastic IPs
- ECR state

The script was validated in two states.

Before destroy, it failed because the EKS cluster still existed.

After destroy, it passed after the Elastic IP check was scoped to project
tags.

This prevents false confidence after cleanup.

V8 demonstrates that cost control is not only a document. It is an operational
check.

## V9 - DevSecOps baseline

V9 added security scanning and dependency governance.

Platform CI now includes a Trivy filesystem scan.

Current policy:

```text
severity: CRITICAL,HIGH
ignore-unfixed: true
exit-code: 1
```

This means the CI blocks fixed high or critical vulnerabilities.

V9 also added Dependabot for:

- GitHub Actions
- Python dependencies
- Terraform dependencies
- Docker base images

Multiple Dependabot pull requests were reviewed and merged after CI passed.

Some PRs required branch updates because they were created before a workflow
fix. This validated a realistic dependency governance workflow.

V9 shows that security is part of the platform lifecycle, not an afterthought.

## Current final state

At the end of V9, the project demonstrates:

- infrastructure as code with Terraform
- Kubernetes deployment through Helm
- GitHub Actions OIDC authentication
- controlled manual deployment
- environment approval gates
- namespace-scoped RBAC
- observability with Prometheus and Grafana
- alerting with PrometheusRule
- SRE runbooks
- Helm rollback
- self-service onboarding model
- FinOps cleanup verification
- DevSecOps scanning and dependency governance

## Operating model

The project follows a clear operating model.

Infrastructure lifecycle:

```text
make tf-apply
make tf-destroy
```

Application lifecycle:

```text
GitHub Actions deploy workflow
-> Helm upgrade
-> rollout validation
-> smoke test
```

Incident lifecycle:

```text
alert
-> runbook
-> diagnosis
-> recovery
-> post-recovery checks
```

Cleanup lifecycle:

```text
terraform destroy
-> AWS cleanup verification script
-> no remaining project cost drivers
```

## What this project proves

This project proves the ability to design and validate a platform golden path
across several dimensions:

- cloud infrastructure
- Kubernetes operations
- CI/CD automation
- IAM and OIDC security
- observability
- SRE alerting
- release safety
- developer self-service
- FinOps
- DevSecOps

The value is not only in the individual tools. The value is in the way they
are connected into a coherent operating model.

## Future improvements

Useful future iterations could include:

- architecture diagram polish
- Grafana dashboard as code
- deploy-existing-image-only workflow
- ECR lifecycle policy hardening
- SBOM generation
- image signing with Cosign
- policy-as-code with Kyverno or OPA Gatekeeper
- a second example service using the onboarding checklist

These are not required for the current platform baseline, but they are natural
extensions.