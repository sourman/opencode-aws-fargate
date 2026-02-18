#!/bin/bash
set -e

AWS_REGION=${AWS_REGION:-us-east-1}
FUNCTION_NAME="opencode-agent-dns-updater"

echo "Triggering DNS update Lambda function..."
aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --payload '{}' \
  /tmp/lambda-response.json

echo ""
echo "Response:"
cat /tmp/lambda-response.json | jq -r '.body' | jq .
echo ""

if [ -f /tmp/lambda-response.json ]; then
  rm /tmp/lambda-response.json
fi


