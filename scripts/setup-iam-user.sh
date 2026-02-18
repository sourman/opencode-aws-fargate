#!/bin/bash
set -e

USER_NAME="opencode-terraform-user"
POLICY_NAME="${USER_NAME}-policy"
AWS_REGION=${AWS_REGION:-us-east-1}

echo "=== Creating IAM User for Terraform ==="
echo "User name: $USER_NAME"
echo ""

# Check if we're using root/admin credentials
CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "")
if [[ -z "$CURRENT_USER" ]]; then
  echo "Error: AWS credentials not configured"
  exit 1
fi

echo "Current AWS identity: $CURRENT_USER"
echo ""

# Check if user already exists
if aws iam get-user --user-name "$USER_NAME" &>/dev/null; then
  echo "User $USER_NAME already exists. Skipping user creation."
  USER_EXISTS=true
else
  echo "Creating IAM user: $USER_NAME"
  aws iam create-user --user-name "$USER_NAME" --tags Key=Purpose,Value=Terraform Key=Project,Value=OpenCode
  USER_EXISTS=false
fi

# Create comprehensive policy document
echo "Creating comprehensive IAM policy..."
POLICY_DOC=$(cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "ecr:*",
        "elasticfilesystem:*",
        "elasticloadbalancing:*",
        "iam:*",
        "logs:*",
        "secretsmanager:*",
        "dynamodb:*",
        "cloudwatch:*",
        "route53:*",
        "lambda:*",
        "events:*",
        "sts:GetCallerIdentity",
        "sts:AssumeRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

# Check if policy already exists
if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME" &>/dev/null 2>&1; then
  echo "Policy $POLICY_NAME already exists. Updating..."
  POLICY_ARN=$(aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME" --query 'Policy.Arn' --output text)
  
  # Create new policy version
  POLICY_VERSION=$(aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document "$POLICY_DOC" \
    --set-as-default \
    --query 'PolicyVersion.VersionId' \
    --output text)
  echo "Policy updated. Version: $POLICY_VERSION"
else
  echo "Creating new policy: $POLICY_NAME"
  POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOC" \
    --query 'Policy.Arn' \
    --output text)
  echo "Policy created: $POLICY_ARN"
fi

# Attach policy to user
echo "Attaching policy to user..."
aws iam attach-user-policy \
  --user-name "$USER_NAME" \
  --policy-arn "$POLICY_ARN" || echo "Policy may already be attached"

# Create access keys
echo ""
echo "Creating access keys..."
if [ "$USER_EXISTS" = true ]; then
  # List existing keys
  EXISTING_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
  if [ -n "$EXISTING_KEYS" ]; then
    echo "User already has access keys. Creating new ones (old keys will be deleted)..."
    for key in $EXISTING_KEYS; do
      aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$key" 2>/dev/null || true
    done
  fi
fi

KEY_OUTPUT=$(aws iam create-access-key --user-name "$USER_NAME")
ACCESS_KEY_ID=$(echo "$KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "$KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')

echo ""
echo "=== Access Keys Created ==="
echo "Access Key ID: $ACCESS_KEY_ID"
echo "Secret Access Key: $SECRET_ACCESS_KEY"
echo ""
echo "=== Configuring AWS CLI ==="

# Configure AWS CLI
aws configure set aws_access_key_id "$ACCESS_KEY_ID" --profile default
aws configure set aws_secret_access_key "$SECRET_ACCESS_KEY" --profile default
aws configure set region "$AWS_REGION" --profile default
aws configure set output json --profile default

echo "AWS CLI configured successfully!"
echo ""

# Verify the new credentials
echo "Verifying new credentials..."
NEW_IDENTITY=$(aws sts get-caller-identity --query Arn --output text)
echo "New AWS identity: $NEW_IDENTITY"
echo ""

echo "=== Setup Complete ==="
echo "IAM user created and AWS CLI configured."
echo "You can now run: make deploy"

