.PHONY: help build push deploy destroy plan apply set-secrets logs status

AWS_REGION ?= us-east-1
PROJECT_NAME ?= opencode-agent

help:
	@echo "Available targets:"
	@echo "  build        - Build Docker image"
	@echo "  push         - Push Docker image to ECR"
	@echo "  deploy       - Deploy infrastructure and update service"
	@echo "  plan         - Show Terraform plan"
	@echo "  apply        - Apply Terraform changes"
	@echo "  destroy      - Destroy all infrastructure"
	@echo "  set-secrets  - Set API keys in Secrets Manager"
	@echo "  logs         - Tail ECS container logs"
	@echo "  status       - Show deployment status"
	@echo "  open         - Open OpenCode in browser"
	@echo "  update-dns   - Manually update DNS record"

build:
	./scripts/build-and-push.sh

push: build

deploy:
	./scripts/deploy.sh

plan:
	cd infrastructure/terraform && terraform plan

apply:
	cd infrastructure/terraform && terraform apply

destroy:
	cd infrastructure/terraform && terraform destroy

set-secrets:
	./scripts/set-secrets.sh

logs:
	aws logs tail /ecs/$(PROJECT_NAME) --follow --region $(AWS_REGION)

status:
	@echo "=== ECS Service Status ==="
	@aws ecs describe-services \
		--cluster $(PROJECT_NAME)-cluster \
		--services $(PROJECT_NAME)-service \
		--region $(AWS_REGION) \
		--query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Deployments:deployments[*].{Status:status,TaskDef:taskDefinition}}' \
		--output table || echo "Service not found"
	@echo ""
	@echo "=== DNS Information ==="
	@cd infrastructure/terraform && terraform output -raw dns_name 2>/dev/null | xargs -I {} echo "DNS Name: {}" || echo "DNS not configured"
	@echo ""
	@echo "=== Getting Task Public IP ==="
	@./scripts/get-task-ip.sh 2>/dev/null || echo "No running tasks yet"

update-dns:
	./scripts/update-dns.sh

open:
	./scripts/open-opencode.sh


