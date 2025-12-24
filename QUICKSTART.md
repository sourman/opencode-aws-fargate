# Quick Start Guide

Get OpenCode running on AWS Fargate in 5 minutes!

## Prerequisites Check

```bash
# Verify AWS CLI is configured
aws sts get-caller-identity

# Verify Docker is running
docker ps

# Verify Terraform is installed
terraform version
```

## Step 1: Set API Keys

```bash
./scripts/set-secrets.sh
```

Enter your Anthropic API key when prompted. You can skip OpenAI if you don't need it.

Alternatively, you can set them via environment variables:

```bash
export ANTHROPIC_API_KEY="your-key-here"
export OPENAI_API_KEY="your-key-here"  # optional
```

Then create the secret manually:

```bash
aws secretsmanager create-secret \
  --name opencode-agent-llm-keys \
  --secret-string "{\"ANTHROPIC_API_KEY\":\"$ANTHROPIC_API_KEY\",\"OPENAI_API_KEY\":\"$OPENAI_API_KEY\"}"
```

## Step 2: Deploy Everything

```bash
make deploy
```

Or manually:

```bash
./scripts/deploy.sh
```

This will:
1. Create all AWS infrastructure (VPC, ECS, EFS, ALB, etc.)
2. Build and push the Docker image
3. Deploy the ECS service

**Wait 2-3 minutes** for the service to become healthy.

## Step 3: Access OpenCode

Get the load balancer URL:

```bash
cd infrastructure/terraform
terraform output alb_dns_name
```

Or use the Makefile:

```bash
make status
```

Open the URL in your browser - you should see the OpenCode web UI!

## Common Commands

```bash
# View logs
make logs

# Check service status
make status

# Update API keys
make set-secrets
# Then restart the service:
aws ecs update-service \
  --cluster opencode-agent-cluster \
  --service opencode-agent-service \
  --force-new-deployment

# Destroy everything
make destroy
```

## Troubleshooting

### Service won't start

```bash
# Check ECS service events
aws ecs describe-services \
  --cluster opencode-agent-cluster \
  --services opencode-agent-service \
  --query 'services[0].events[:5]'

# Check container logs
make logs

# Check task status
aws ecs list-tasks \
  --cluster opencode-agent-cluster \
  --service-name opencode-agent-service
```

### Can't access the URL

1. Check security groups allow traffic from your IP
2. Verify the ALB target group health checks are passing
3. Check CloudWatch logs for errors

### EFS mount issues

```bash
# Get a shell in the container
TASK_ID=$(aws ecs list-tasks \
  --cluster opencode-agent-cluster \
  --service-name opencode-agent-service \
  --query 'taskArns[0]' --output text | cut -d'/' -f3)

aws ecs execute-command \
  --cluster opencode-agent-cluster \
  --task $TASK_ID \
  --container opencode-container \
  --command "/bin/bash" \
  --interactive

# In the container, check EFS:
ls -la /mnt/efs/workspace
```

## Next Steps

- Configure HTTPS (see README.md)
- Scale the service (edit `desired_count` in `infrastructure/terraform/ecs.tf`)
- Set up monitoring and alerts
- Configure custom domain


