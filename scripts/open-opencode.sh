#!/bin/bash
set -e

CLUSTER_NAME=${CLUSTER_NAME:-opencode-agent-cluster}
SERVICE_NAME=${SERVICE_NAME:-opencode-agent-service}
AWS_REGION=${AWS_REGION:-us-east-1}

echo "Getting task IP for service: $SERVICE_NAME"

TASK_ARN=$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'taskArns[0]' \
  --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
  echo "No running tasks found. Service may still be starting..."
  exit 1
fi

NETWORK_INTERFACE_ID=$(aws ecs describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks "$TASK_ARN" \
  --region "$AWS_REGION" \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

if [ -z "$NETWORK_INTERFACE_ID" ] || [ "$NETWORK_INTERFACE_ID" == "None" ]; then
  echo "Could not find network interface"
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$NETWORK_INTERFACE_ID" \
  --region "$AWS_REGION" \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" == "None" ]; then
  echo "Could not find public IP"
  exit 1
fi

URL="http://$PUBLIC_IP:4096"

echo ""
echo "=== Opening OpenCode ==="
echo "URL: $URL"
echo ""

# Try different methods to open browser based on environment
if command -v wslview &> /dev/null; then
  # WSL2
  echo "Opening in browser (WSL)..."
  wslview "$URL"
elif command -v xdg-open &> /dev/null; then
  # Linux with X11
  echo "Opening in browser (X11)..."
  xdg-open "$URL"
elif command -v open &> /dev/null; then
  # macOS
  echo "Opening in browser (macOS)..."
  open "$URL"
else
  echo "Could not auto-open browser. Please open this URL manually:"
  echo "$URL"
fi


