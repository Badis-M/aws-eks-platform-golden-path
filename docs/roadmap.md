

# Platform Roadmap

This document describes the future roadmap for the AWS EKS Platform Golden Path.

The README keeps a short recruiter-friendly summary. This roadmap provides the
broader technical direction for the project.

## Current baseline

The platform currently validates three major milestones.

### V1 - Platform foundation

V1 validates the core cloud-native delivery path:

- FastAPI application
- Docker image build
- Amazon ECR repository
- Terraform-managed AWS infrastructure
- Amazon EKS cluster
- Helm deployment
- GitHub Actions CI
- GitHub OIDC foundation
- S3 remote Terraform backend
- cost-aware destroy workflow

### V2 - Observability

V2 validates Kubernetes observability on EKS:

- kube-prometheus-stack
- Prometheus Operator
- Prometheus scraping
- Grafana Explore
- ServiceMonitor discovery
- application metrics exposed through `/metrics`
- request-rate visualization by route

### V3 - Controlled manual deployment automation

V3 validates manual deployment automation without automatic infrastructure
creation:

- `workflow_dispatch` deployment workflow
- optional GitHub Environment `dev` approval model
- GitHub OIDC authentication
- dedicated least-privilege deploy role
- EKS access entry for the deploy role
- namespace-scoped Kubernetes RBAC
- commit-SHA Docker image tagging
- Helm deployment to an existing EKS cluster
- in-cluster smoke test for `/health` and `/ready`
- observability-enabled deployment mode with ServiceMonitor creation

## Roadmap principles

Future versions should keep the same project principles:

- security-first design
- least privilege by default
- no static AWS credentials
- no uncontrolled AWS cost on push
- clear separation between infrastructure lifecycle and application deployment
- short-lived cloud environments
- clean documentation and interview-ready explanations
- realistic DevOps, SRE, and Platform Engineering workflows

## V4 - Production-grade hardening

Goal: improve the platform from a validated lab into a more production-like
foundation.

Candidate scope:

- add proper `fullnameOverride` support to the Helm chart
- standardize Helm naming across Deployment, Service, and ServiceMonitor
- add GitHub Environment approval requirements for `dev`
- tighten the Terraform Plan IAM policy instead of relying on `ReadOnlyAccess`
- review and reduce Kubernetes RBAC permissions where possible
- add NetworkPolicy for the `incident-api` namespace
- split Helm values by deployment mode:
  - `values-dev.yaml`
  - `values-observability.yaml`
  - `values-ci.yaml`
- document known risks and accepted trade-offs

Expected outcome:

```text
The platform keeps the same working V3 deployment model, but with cleaner Helm
conventions, stronger access controls, and more explicit operating boundaries.
```

Interview value:

```text
This version demonstrates security hardening, governance, IAM discipline,
Kubernetes RBAC maturity, and production-readiness thinking.
```

## V5 - SRE alerting and incident operations

Goal: move from observability to operational readiness.

Candidate scope:

- add Prometheus alert rules
- alert on Pod availability
- alert on container restarts
- alert on readiness failures
- alert on HTTP error rate
- add latency metrics if the application exposes them
- create a Grafana dashboard as code
- add an incident runbook for common failure modes
- simulate a controlled incident and document the response

Example alerting topics:

- API unavailable
- high restart count
- failing readiness probe
- elevated 5xx rate
- missing Prometheus scrape target

Expected outcome:

```text
The platform can detect common application and Kubernetes failures, explain
how to investigate them, and provide clear operator runbooks.
```

Interview value:

```text
This version demonstrates SRE thinking, incident response, alert design,
operational maturity, and practical troubleshooting.
```

## V6 - Progressive delivery and release strategy

Goal: reduce deployment risk with controlled release patterns.

Candidate scope:

- add Helm rollback documentation
- add manual rollback workflow
- deploy a specific image tag from workflow input
- support release promotion between environments
- introduce a staging-like namespace
- evaluate blue-green or canary deployment patterns
- document release criteria and rollback criteria

Possible workflow inputs:

```text
image_tag
target_environment
enable_observability
rollback_revision
```

Expected outcome:

```text
The deployment process supports safer release operations, explicit image
promotion, and documented rollback procedures.
```

Interview value:

```text
This version demonstrates release engineering, deployment risk reduction,
rollback strategy, and operational control.
```

## V7 - Platform self-service golden path

Goal: make the project feel like a reusable internal developer platform.

Candidate scope:

- document how to onboard a new service
- define required application conventions:
  - `/health`
  - `/ready`
  - `/metrics`
  - resource requests and limits
  - labels and annotations
  - Helm values structure
- add a second example microservice
- create a service onboarding checklist
- provide a reusable Helm chart pattern
- document team responsibilities between platform and application owners

Expected outcome:

```text
A developer can follow the platform documentation and onboard a new service
using the same CI, deployment, observability, and RBAC conventions.
```

Interview value:

```text
This version demonstrates Platform Engineering thinking: building reusable
paved roads for development teams instead of one-off infrastructure.
```

## V8 - FinOps automation and cloud governance

Goal: strengthen the cost-control and governance dimension of the platform.

Candidate scope:

- document expected AWS cost drivers
- add AWS Budget or budget alert documentation
- add required tagging validation
- add a manual cost-check workflow
- add scripts to detect leftover resources
- document the cleanup process after validation sessions
- add a cost-aware deployment checklist
- make the ephemeral lifecycle more visible in the README

Cost-sensitive resources:

- EKS control plane
- managed node group EC2 instances
- NAT Gateway if introduced later
- EBS volumes
- load balancers if introduced later
- retained container images in ECR

Expected outcome:

```text
The platform documents and enforces cost-awareness, making cloud spend part of
the operating model rather than an afterthought.
```

Interview value:

```text
This version demonstrates FinOps awareness, cloud governance, tagging
discipline, and responsible AWS operations.
```

## V9 - DevSecOps and supply-chain security

Goal: add security checks to the delivery pipeline.

Candidate scope:

- scan Docker images with Trivy
- scan Terraform code with a security scanner
- scan Kubernetes manifests and Helm output
- add Dependabot for application dependencies and GitHub Actions
- generate an SBOM for the application image
- document image vulnerability handling
- enforce minimal GitHub Actions permissions
- review branch protection recommendations

Possible validation layers:

```text
application dependencies
container image
Terraform code
Kubernetes manifests
GitHub Actions workflow permissions
```

Expected outcome:

```text
The platform validates not only whether the application works, but also
whether the delivery path meets baseline security expectations.
```

Interview value:

```text
This version demonstrates DevSecOps maturity, supply-chain awareness, and CI/CD
security controls.
```

## V10 - Portfolio polish and public presentation

Goal: make the project easy to understand for recruiters, hiring managers, and
technical interviewers.

Candidate scope:

- add architecture diagrams
- add screenshots of GitHub Actions workflows
- add screenshots of Grafana dashboards
- add release notes for V1, V2, and V3
- add a concise project summary for portfolio use
- add a LinkedIn post draft
- add interview talking points
- add a decision log for major architecture choices

Suggested public narrative:

```text
This project demonstrates a cost-aware AWS EKS golden path with Terraform,
GitHub OIDC, Helm, Kubernetes RBAC, Prometheus, Grafana, and controlled manual
deployment automation.
```

Expected outcome:

```text
The repository becomes easy to review quickly while still offering enough
technical depth for senior DevOps, SRE, and Platform Engineering interviews.
```

Interview value:

```text
This version demonstrates not only technical implementation, but also the
ability to communicate architecture, trade-offs, operational practices, and
project outcomes clearly.
```

## Recommended next order

The recommended sequence is:

```text
V4  - Production-grade hardening
V5  - SRE alerting and incident operations
V8  - FinOps automation and cloud governance
V9  - DevSecOps and supply-chain security
V10 - Portfolio polish and public presentation
```

V6 and V7 are valuable, but they can wait until the platform is more hardened.

## Short README roadmap

The README should keep only a short roadmap:

```text
- Add V3 release note and tag v3.0.0
- Add production-grade hardening
- Add SRE alerting and incident runbooks
- Add DevSecOps and supply-chain checks
- Add portfolio architecture diagram and demo screenshots
```

The detailed roadmap belongs in this file to keep the README concise and easy
to scan.