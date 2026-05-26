.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  make app-test        Run FastAPI tests"
	@echo "  make app-run         Run FastAPI locally"
	@echo "  make app-metrics     Validate the local Prometheus metrics endpoint"
	@echo "  make docker-build    Build local Docker image"
	@echo ""
	@echo "  make helm-lint       Validate Helm chart"
	@echo "  make helm-template   Render Helm manifests"
	@echo "  make helm-validate   Validate Helm chart and rendered observability annotations"
	@echo "  make helm-deploy     Deploy API with Helm"
	@echo ""
	@echo "  make tf-init         Initialize Terraform"
	@echo "  make tf-plan         Plan Terraform changes"
	@echo "  make tf-apply        Apply Terraform changes"
	@echo "  make tf-destroy      Destroy Terraform-managed infrastructure"
	@echo "  make observability-check  Validate app metrics and Helm scrape annotations"
	@echo ""

.PHONY: app-run
app-run:
	cd $(APP_DIR) && uvicorn app.main:app --host 0.0.0.0 --port 8000

.PHONY: app-metrics
app-metrics:
	cd $(APP_DIR) && pytest tests/test_health.py -k metrics

.PHONY: helm-template
helm-template:
	helm template incident-api $(HELM_CHART)

.PHONY: helm-validate
helm-validate: helm-lint helm-template
	helm template incident-api $(HELM_CHART) | grep 'prometheus.io/scrape: "true"'
	helm template incident-api $(HELM_CHART) | grep 'prometheus.io/path: /metrics'
	helm template incident-api $(HELM_CHART) | grep 'prometheus.io/port: "8000"'

.PHONY: tf-destroy
tf-destroy:
	cd $(TF_DIR) && terraform destroy

.PHONY: observability-check
observability-check: app-metrics helm-validate
