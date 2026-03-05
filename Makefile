# ============================================
# EKS Infrastructure Makefile
# ============================================

.PHONY: help init plan apply destroy fmt validate clean dev staging prod

# Default target
help:
	@echo "EKS Infrastructure Management"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Setup:"
	@echo "  init        Initialize Terraform"
	@echo "  validate    Validate Terraform configuration"
	@echo "  fmt         Format Terraform files"
	@echo ""
	@echo "Deployment:"
	@echo "  dev         Deploy to development environment"
	@echo "  staging     Deploy to staging environment"
	@echo "  prod        Deploy to production environment"
	@echo ""
	@echo "Management:"
	@echo "  plan        Show execution plan"
	@echo "  apply       Apply changes"
	@echo "  destroy     Destroy infrastructure"
	@echo "  clean       Clean up temporary files"
	@echo ""
	@echo "Utilities:"
	@echo "  kubeconfig  Configure kubectl"
	@echo "  backup      Create Velero backup"
	@echo "  status      Show cluster status"

# Initialize Terraform
init:
	terraform init

# Validate configuration
validate:
	terraform validate

# Format Terraform files
fmt:
	terraform fmt -recursive

# Show plan
plan:
	@read -p "Environment (dev/staging/prod): " env; \
	terraform workspace select $$env && terraform plan -var-file=environments/$$env.tfvars

# Apply changes
apply:
	@read -p "Environment (dev/staging/prod): " env; \
	terraform workspace select $$env && terraform apply -var-file=environments/$$env.tfvars

# Destroy infrastructure
destroy:
	@read -p "Environment (dev/staging/prod): " env; \
	read -p "Are you sure? This will DELETE all resources! [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		terraform workspace select $$env && terraform destroy -var-file=environments/$$env.tfvars; \
	else \
		echo "Aborted"; \
	fi

# Deploy to dev
dev:
	terraform workspace new dev 2>/dev/null || terraform workspace select dev
	terraform apply -var-file=environments/dev.tfvars

# Deploy to staging
staging:
	terraform workspace new staging 2>/dev/null || terraform workspace select staging
	terraform apply -var-file=environments/staging.tfvars

# Deploy to prod
prod:
	@read -p "Are you sure you want to deploy to PRODUCTION? [yes/N] " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		terraform workspace new prod 2>/dev/null || terraform workspace select prod; \
		terraform apply -var-file=environments/prod.tfvars; \
	else \
		echo "Aborted"; \
	fi

# Clean up temporary files
clean:
	rm -rf .terraform/
	rm -f terraform.tfstate.backup
	rm -f *.tfplan
	rm -f crash.log

# Configure kubectl
kubeconfig:
	@read -p "Environment (dev/staging/prod): " env; \
	aws eks update-kubeconfig --region us-west-2 --name todo-app-$$env

# Create backup
backup:
	@read -p "Backup name: " name; \
	velero backup create $$name-$(shell date +%Y%m%d)

# Show cluster status
status:
	@echo "=== Cluster Status ==="
	@kubectl cluster-info 2>/dev/null || echo "kubectl not configured"
	@echo ""
	@echo "=== Nodes ==="
	@kubectl get nodes 2>/dev/null || echo "No nodes found"
	@echo ""
	@echo "=== Pods ==="
	@kubectl get pods --all-namespaces 2>/dev/null || echo "No pods found"

# Full setup for new environment
setup: init validate
	@echo "Infrastructure setup complete. Run 'make dev' to deploy."

# Lint Helm charts
lint:
	helm lint ./helm_charts/todo-frontend
	helm lint ./helm_charts/todo-backend

# Template Helm charts
template:
	helm template todo-frontend ./helm_charts/todo-frontend
	helm template todo-backend ./helm_charts/todo-backend
