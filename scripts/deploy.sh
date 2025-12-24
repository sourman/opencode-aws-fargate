#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infrastructure/terraform"

cd "$INFRA_DIR"

echo "Initializing Terraform..."
terraform init

echo "Planning Terraform changes..."
terraform plan

echo "Applying Terraform changes..."
terraform apply -auto-approve

echo "Building and pushing Docker image..."
cd "$PROJECT_ROOT"
./scripts/build-and-push.sh

echo "Updating ECS service to use new image..."
CLUSTER_NAME=$(terraform -chdir="$INFRA_DIR" output -raw ecs_cluster_name)
SERVICE_NAME="opencode-agent-service"
AWS_REGION=${AWS_REGION:-us-east-1}

# Check if service exists, if not it will be created by Terraform
if aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0].status' \
  --output text 2>/dev/null | grep -q "ACTIVE"; then
  echo "Service exists, forcing new deployment..."
  aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --force-new-deployment \
    --region "$AWS_REGION"
else
  echo "Service will be created by Terraform (if not already created)"
fi

echo ""
echo "=== Deployment complete! ==="
echo "Load Balancer DNS: $(terraform -chdir="$INFRA_DIR" output -raw alb_dns_name)"
echo ""
echo "Note: It may take 2-3 minutes for the service to become healthy."
echo "Check status with: make status"

