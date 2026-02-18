# OpenCode Agent on AWS Fargate

This project deploys the OpenCode agent on AWS Fargate with persistent storage, per-user chat sessions, and shared LLM provider API keys.

## Architecture

- **ECS Fargate**: Runs OpenCode containers with public IPs
- **EFS (Elastic File System)**: Persistent storage for workspace and session data
- **Secrets Manager**: Stores LLM API keys (shared across all users)
- **DynamoDB**: Optional session metadata tracking
- **ECR**: Container image registry

**Note**: This setup uses direct access via ECS task public IPs (no load balancer) for simplicity.

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0
3. Docker
4. jq (for scripts)

## Quick Start

### 1. Set up API Keys

```bash
./scripts/set-secrets.sh
```

Or manually create the secret in AWS Secrets Manager:
- Secret name: `opencode-agent-llm-keys`
- Keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`

### 2. Deploy Infrastructure

```bash
./scripts/deploy.sh
```

This will:
- Create all AWS resources using Terraform
- Build and push the Docker image to ECR
- Deploy the ECS service

### 3. Configure DNS (One-time setup)

Update your domain registrar with Route53 name servers. See `DNS_SETUP.md` for detailed instructions.

**Name servers** (get current values with `terraform output name_servers`):
- ns-1328.awsdns-38.org
- ns-1931.awsdns-49.co.uk
- ns-257.awsdns-32.com
- ns-899.awsdns-48.net

### 4. Access OpenCode

Once DNS is configured and tasks are running, access OpenCode at:

**URL**: `http://agent.compliancy-csm.xyz:4096`

The DNS record automatically updates when tasks start/stop. You can also manually update it:

```bash
make update-dns
# or
./scripts/update-dns.sh
```

## Manual Deployment Steps

### 1. Build and Push Docker Image

```bash
./scripts/build-and-push.sh
```

### 2. Deploy Infrastructure with Terraform

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### 3. Update API Keys (if needed)

```bash
./scripts/set-secrets.sh
```

Then restart the ECS service:

```bash
aws ecs update-service \
  --cluster opencode-agent-cluster \
  --service opencode-agent-service \
  --force-new-deployment
```

## Configuration

### Environment Variables

Edit `infrastructure/terraform/variables.tf` or create `terraform.tfvars`:

```hcl
aws_region         = "us-east-1"
anthropic_api_key  = "your-key"
openai_api_key     = "your-key"
enable_https       = false
```

### Scaling

Edit `infrastructure/terraform/ecs.tf` to change:
- `desired_count` in `aws_ecs_service.opencode`
- `cpu` and `memory` in `aws_ecs_task_definition.opencode`

### Persistent Storage

All workspace data is stored in EFS at `/mnt/efs/workspace` in the container. This persists across container restarts and deployments.

## Session Management

OpenCode manages its own sessions. The load balancer uses sticky sessions (cookie-based) to route users to the same container instance, ensuring session continuity.

For advanced session tracking, you can use the DynamoDB table `opencode-agent-sessions` to store session metadata.

## Monitoring

- **CloudWatch Logs**: `/ecs/opencode-agent`
- **ECS Service**: View in AWS Console → ECS → Clusters → opencode-agent-cluster
- **Load Balancer**: View target health in ALB console

## Troubleshooting

### View Container Logs

```bash
aws logs tail /ecs/opencode-agent --follow
```

### Execute Commands in Container

```bash
aws ecs execute-command \
  --cluster opencode-agent-cluster \
  --task TASK_ID \
  --container opencode-container \
  --command "/bin/bash" \
  --interactive
```

### Check EFS Mount

```bash
# In container
ls -la /mnt/efs/workspace
```

### Restart Service

```bash
aws ecs update-service \
  --cluster opencode-agent-cluster \
  --service opencode-agent-service \
  --force-new-deployment
```

## Cost Optimization

- EFS: Use lifecycle policies (already configured to transition to IA after 30 days)
- ECS: Use Fargate Spot for non-production (add to task definition)
- ALB: Consider using NLB for lower cost if you don't need ALB features

## Security

- API keys stored in Secrets Manager (encrypted at rest)
- EFS uses transit encryption
- Security groups restrict access
- HTTPS can be enabled by setting `enable_https = true` and providing a certificate ARN

## Cleanup

```bash
cd infrastructure/terraform
terraform destroy
```

This will remove all resources. Note: EFS data will be deleted. Back up important data first.


