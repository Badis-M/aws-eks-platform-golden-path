# V9 DevSecOps

V9 adds DevSecOps controls to the AWS EKS Platform Golden Path.

The goal is to make security scanning and dependency governance part of the
normal platform workflow.

## Scope

V9 focuses on two practical controls:

- security scanning in Platform CI
- dependency update governance with Dependabot

This release does not try to implement the full software supply chain stack.
It adds a lightweight baseline that is useful, visible, and maintainable.

## Security scan in Platform CI

Platform CI now includes a dedicated security job.

The job uses Trivy to scan the repository filesystem:

```text
aquasecurity/trivy-action
```

Current scan mode:

```text
scan-type: fs
scan-ref: .
severity: CRITICAL,HIGH
ignore-unfixed: true
exit-code: 1
format: table
```

This means CI fails when Trivy finds high or critical fixed vulnerabilities.

## Why filesystem scanning first

Filesystem scanning is a good first DevSecOps gate because it can inspect:

- dependency files
- Dockerfiles
- Infrastructure as Code files
- application manifests
- repository configuration

It does not require a running EKS cluster or a pushed container image.

This keeps the check compatible with the project's cost-aware model.

## Dependency governance

V9 adds Dependabot configuration in:

```text
.github/dependabot.yml
```

Dependabot monitors:

- GitHub Actions
- Python dependencies
- Terraform dependencies
- Docker base images

This makes dependency drift visible through pull requests instead of hidden in
the repository.

## Dependabot workflow

The expected workflow is:

```text
Dependabot opens PR
-> Platform CI runs
-> review changed files
-> merge only if checks pass
-> debug or close noisy PRs
```

Dependabot PRs should not be merged blindly.

Each update must keep the platform stable and understandable.

## Pull request handling

If a Dependabot PR fails because it was created before a workflow fix, update
the PR branch with the latest `main`.

Recommended commands:

```bash
gh pr checkout <PR_NUMBER>
git fetch origin main
git merge origin/main --no-edit
git push
git checkout main
git pull
```

This updates the PR branch without merging it into `main`.

GitHub Actions then reruns CI on the updated pull request.

## Current validated updates

During V9, multiple dependency PRs were handled and merged after CI passed.

Examples included updates for:

- GitHub Actions
- Trivy GitHub Action
- Python dependencies
- Docker base image
- Terraform provider lockfile

The local `main` branch was then synchronized with `origin/main`.

## Security boundaries

V9 does not grant new cloud permissions.

It does not change the AWS IAM model.

It does not change Kubernetes runtime permissions.

The DevSecOps changes run in CI and dependency management only.

## Current limitations

V9 does not include:

- SBOM generation
- image signing
- Cosign
- SLSA provenance
- Kyverno policies
- OPA Gatekeeper policies
- registry admission control
- runtime security monitoring

These remain future enhancements.

## Operational notes

Trivy can create noise when dependencies or base images have vulnerabilities.

The current policy is strict enough to catch important issues, but scoped
enough to remain usable:

```text
severity: CRITICAL,HIGH
ignore-unfixed: true
exit-code: 1
```

This means unresolved vulnerabilities without fixes are not blocking yet.

## Final V9 outcome

V9 adds a repeatable DevSecOps baseline:

```text
dependency visibility
-> automated update PRs
-> CI security scan
-> review before merge
-> stable main branch
```