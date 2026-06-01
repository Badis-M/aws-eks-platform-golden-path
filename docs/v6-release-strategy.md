# V6 Release Strategy

V6 adds a controlled release and rollback strategy to the AWS EKS Platform
Golden Path.

The goal is to make application delivery safer without adding unnecessary
deployment complexity.

## Scope

V6 focuses on two practical release operations:

- deploy a specific image tag when needed
- rollback an existing Helm release to a previous revision

This keeps the platform simple while adding an operational safety net.

## Deployment model

The Incident API deployment workflow remains manual.

The deployment flow is:

```text
workflow_dispatch
-> GitHub Environment dev approval
-> GitHub OIDC role assumption
-> Docker image build and push
-> Helm upgrade
-> rollout validation
-> in-cluster smoke test
```

## Explicit image tag support

The `Deploy Incident API` workflow now accepts an optional input:

```text
image_tag
```

If `image_tag` is empty, the workflow uses the current commit SHA.

```text
image_tag empty
-> IMAGE_TAG=github.sha
```

If `image_tag` is provided, the workflow uses that value.

```text
image_tag provided
-> IMAGE_TAG=<provided value>
```

This allows controlled image tagging while keeping the default behavior safe
and traceable.

## Current image tag behavior

The deploy workflow still builds and pushes the application image during each
deployment run.

This means:

```text
image_tag provided
-> build current source code
-> push image with provided tag
-> deploy that tag
```

It does not yet implement a pure "deploy existing image without rebuild"
workflow.

That behavior can be added later if a stronger promotion model is needed.

## Rollback workflow

V6 adds a dedicated manual rollback workflow:

```text
.github/workflows/rollback-incident-api.yml
```

The rollback workflow accepts a required Helm revision:

```text
revision
```

It performs:

```text
workflow_dispatch
-> GitHub Environment dev approval
-> GitHub OIDC role assumption
-> EKS kubeconfig update
-> helm history
-> helm rollback <revision>
-> Kubernetes rollout status
-> in-cluster smoke test
```

## Rollback boundaries

The rollback workflow does not:

- run Terraform
- create or destroy infrastructure
- build Docker images
- push images to ECR
- grant cluster-admin permissions

It only operates on the existing Helm release in the `incident-api`
namespace.

## Validation

A new deployment revision was created with the deploy workflow.

Helm history showed:

```text
revision 1 -> superseded
revision 2 -> deployed
```

The rollback workflow was then launched with:

```text
revision: 1
```

After rollback, Helm history showed:

```text
revision 1 -> superseded
revision 2 -> superseded
revision 3 -> deployed, Rollback to 1
```

This validates that rollback creates a new Helm revision and restores a
previous release state safely.

## Smoke test

The rollback workflow validates the application after rollback by running an
in-cluster smoke test against:

```text
/health
/ready
```

This confirms that rollback completed and that the application still serves
its core operational endpoints.

## Current limitations

V6 does not add:

- canary deployment
- blue-green deployment
- automated promotion across environments
- deployment freeze windows
- deploy-existing-image-only mode
- automated rollback based on metrics

These remain future release-engineering enhancements.

## Final V6 outcome

V6 validates a controlled release safety loop:

```text
manual deploy
-> explicit image tag option
-> Helm release history
-> manual rollback workflow
-> rollout validation
-> smoke test
```
