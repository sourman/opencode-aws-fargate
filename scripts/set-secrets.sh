#!/bin/bash
set -e

AWS_REGION=${AWS_REGION:-us-east-1}
SECRET_NAME="opencode-agent-llm-keys"

echo "Verifying AWS credentials..."
if ! aws sts get-caller-identity --region "$AWS_REGION" &>/dev/null; then
  echo "Error: AWS credentials not configured or invalid"
  echo "Please run: aws configure"
  exit 1
fi
echo "AWS credentials verified."
echo

read_with_asterisks() {
  local prompt="$1"
  local var_name="$2"
  local value=""
  local char=""
  
  echo -n "$prompt"
  while IFS= read -r -s -n 1 char; do
    if [[ $char == $'\0' ]]; then
      break
    elif [[ $char == $'\177' ]]; then
      if [ ${#value} -gt 0 ]; then
        value="${value%?}"
        echo -ne "\b \b"
      fi
    else
      value+="$char"
      echo -n "*"
    fi
  done
  echo
  eval "$var_name='$value'"
}

read_with_asterisks "Enter Anthropic API Key (direct API key, not subscription): " ANTHROPIC_KEY

if [ -z "$ANTHROPIC_KEY" ]; then
  echo "Error: Anthropic API Key is required"
  exit 1
fi

read_with_asterisks "Enter OpenAI API Key (optional, press Enter to skip): " OPENAI_KEY

SECRET_JSON=$(jq -n \
  --arg anthropic "$ANTHROPIC_KEY" \
  --arg openai "${OPENAI_KEY:-}" \
  '{ANTHROPIC_API_KEY: $anthropic, OPENAI_API_KEY: $openai}')

if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" &>/dev/null; then
  echo "Updating existing secret..."
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$SECRET_JSON" \
    --region "$AWS_REGION"
else
  echo "Creating new secret..."
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "LLM provider API keys for OpenCode agent" \
    --secret-string "$SECRET_JSON" \
    --region "$AWS_REGION"
fi

echo "Secrets updated successfully!"

