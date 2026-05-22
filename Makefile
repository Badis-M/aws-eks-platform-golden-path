APP_DIR := apps/incident-api
HELM_CHART := helm/incident-api
TF_DIR := terraform/environments/dev

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
	@echo "  make docker-build    Build local Docker image"
	@echo "  make ecr-login       Authenticate Docker to AWS ECR"
	@echo "  make ecr-build-push  Build linux/amd64 image and push to ECR"
	@echo "  make helm-lint       Validate Helm chart"
	@echo "  make helm-template   Render Helm manifests"
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

.PHONY: app-test
app-test:
	cd $(APP_DIR) && pytest

.PHONY: app-run
app-run:
	cd $(APP_DIR) && uvicorn app.main:app --host 0.0.0.0 --port 8000

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

.PHONY: tf-destroy
tf-destroy:
	cd $(TF_DIR) && terraform destroy
