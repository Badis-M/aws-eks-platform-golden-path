APP_DIR := apps/incident-api
HELM_CHART := helm/incident-api
TF_DIR := terraform/environments/dev

OBSERVABILITY_VALUES := observability/kube-prometheus-stack-values.yaml
OBSERVABILITY_NAMESPACE := observability
OBSERVABILITY_RELEASE := observability
OBSERVABILITY_CHART := prometheus-community/kube-prometheus-stack

AWS_REGION ?= eu-west-3
AWS_PROFILE ?= tf-eks-golden-path
CLUSTER_NAME ?= aws-eks-platform-golden-path-dev-eks
IMAGE_TAG ?= 0.1.0
ECR_REPOSITORY ?= incident-api
AWS_ACCOUNT_ID ?= 504441516591
ECR_REGISTRY := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
IMAGE_URI := $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG)

.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make app-test        Run FastAPI tests"
	@echo "  make app-run         Run FastAPI locally"
	@echo "  make app-metrics     Validate the local Prometheus metrics endpoint"
	@echo "  make docker-build    Build local Docker image"
	@echo "  make ecr-login       Authenticate Docker to AWS ECR"
	@echo "  make ecr-build-push  Build linux/amd64 image and push to ECR"
	@echo "  make helm-lint       Validate Helm chart"
	@echo "  make helm-template   Render Helm manifests"
	@echo "  make helm-validate   Validate Helm chart and rendered observability annotations"
	@echo "  make helm-deploy     Deploy API with Helm"
	@echo "  make helm-uninstall  Remove Helm release"
	@echo "  make kubeconfig      Update local kubeconfig for EKS"
	@echo "  make kube-pods       List Kubernetes pods"
	@echo "  make tf-fmt          Format Terraform files"
	@echo "  make tf-init         Initialize Terraform"
	@echo "  make tf-validate     Validate Terraform configuration"
	@echo "  make tf-plan         Show Terraform plan"
	@echo "  make tf-apply        Apply Terraform configuration"
	@echo "  make tf-destroy      Destroy Terraform-managed infrastructure"
	@echo "  make ci-foundation-apply  Recreate minimum AWS CI/CD foundation without EKS"
	@echo "  make observability-check    Validate app metrics and Helm scrape annotations"
	@echo "  make observability-repo     Add and update Prometheus community Helm repo"
	@echo "  make observability-template Render kube-prometheus-stack manifests"
	@echo "  make observability-install  Install kube-prometheus-stack on EKS"
	@echo "  make observability-uninstall Remove kube-prometheus-stack from EKS"
	@echo ""
	@echo "AWS resource requirements:"
	@echo "  Backend S3 bucket must exist for Terraform remote state commands."
	@echo "  ecr-login and ecr-build-push require ECR to exist."
	@echo "  Manual GitHub AWS workflows require OIDC provider and IAM roles."
	@echo "  kubeconfig, kube-pods, helm-deploy, helm-uninstall, and observability install/uninstall require the EKS cluster."
	@echo ""
	@echo "Minimum AWS CI/CD foundation after a full dev destroy:"
	@echo "  make ci-foundation-apply"
	@echo ""
	@echo "Equivalent Terraform command:"
	@echo "  cd $(TF_DIR) && terraform apply -target=module.ecr -target=module.iam"

.PHONY: app-test
app-test:
	cd $(APP_DIR) && pytest

.PHONY: app-run
app-run:
	cd $(APP_DIR) && uvicorn app.main:app --host 0.0.0.0 --port 8000

.PHONY: app-metrics
app-metrics:
	cd $(APP_DIR) && pytest tests/test_health.py -k metrics

.PHONY: docker-build
docker-build:
	docker build -t incident-api:$(IMAGE_TAG) $(APP_DIR)

.PHONY: ecr-login
ecr-login:
	aws ecr get-login-password \
		--region $(AWS_REGION) \
		--profile $(AWS_PROFILE) \
	| docker login \
		--username AWS \
		--password-stdin $(ECR_REGISTRY)

.PHONY: ecr-build-push
ecr-build-push:
	docker buildx build \
		--platform linux/amd64 \
		-t $(IMAGE_URI) \
		$(APP_DIR) \
		--push

.PHONY: helm-lint
helm-lint:
	helm lint $(HELM_CHART)

.PHONY: helm-template
helm-template:
	helm template incident-api $(HELM_CHART)

.PHONY: helm-validate
helm-validate: helm-lint helm-template
	helm template incident-api $(HELM_CHART) | grep 'prometheus.io/scrape: "true"'
	helm template incident-api $(HELM_CHART) | grep 'prometheus.io/path: /metrics'
	helm template incident-api $(HELM_CHART) | grep 'prometheus.io/port: "8000"'

.PHONY: helm-deploy
helm-deploy:
	helm upgrade --install incident-api $(HELM_CHART)

.PHONY: helm-uninstall
helm-uninstall:
	helm uninstall incident-api

.PHONY: kubeconfig
kubeconfig:
	aws eks update-kubeconfig \
		--region $(AWS_REGION) \
		--name $(CLUSTER_NAME) \
		--profile $(AWS_PROFILE)

.PHONY: kube-pods
kube-pods:
	kubectl get pods -A

.PHONY: tf-fmt
tf-fmt:
	cd $(TF_DIR) && terraform fmt -recursive

.PHONY: tf-init
tf-init:
	cd $(TF_DIR) && terraform init

.PHONY: tf-validate
tf-validate:
	cd $(TF_DIR) && terraform validate

.PHONY: tf-plan
tf-plan:
	cd $(TF_DIR) && terraform plan

.PHONY: tf-apply
tf-apply:
	cd $(TF_DIR) && terraform apply

.PHONY: ci-foundation-apply
ci-foundation-apply:
	cd $(TF_DIR) && terraform apply -target=module.ecr -target=module.iam

.PHONY: tf-destroy
tf-destroy:
	cd $(TF_DIR) && terraform destroy


.PHONY: observability-check
observability-check: app-metrics helm-validate

.PHONY: observability-repo
observability-repo:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

.PHONY: observability-template
observability-template: observability-repo
	helm template $(OBSERVABILITY_RELEASE) $(OBSERVABILITY_CHART) \
		--namespace $(OBSERVABILITY_NAMESPACE) \
		--values $(OBSERVABILITY_VALUES)

.PHONY: observability-install
observability-install: observability-repo
	helm upgrade --install $(OBSERVABILITY_RELEASE) $(OBSERVABILITY_CHART) \
		--namespace $(OBSERVABILITY_NAMESPACE) \
		--create-namespace \
		--values $(OBSERVABILITY_VALUES)

.PHONY: observability-uninstall
observability-uninstall:
	helm uninstall $(OBSERVABILITY_RELEASE) --namespace $(OBSERVABILITY_NAMESPACE)
