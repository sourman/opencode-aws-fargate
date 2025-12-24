# Architecture Overview

This document describes the AWS infrastructure architecture for running OpenCode on Fargate.

## High-Level Architecture

```
Internet
   │
   ▼
Application Load Balancer (ALB)
   │
   ├─ Sticky Sessions (Cookie-based)
   │
   ▼
ECS Fargate Tasks (OpenCode Containers)
   │
   ├─ Port 4096 (OpenCode Server)
   │
   ├─ EFS Mount (/mnt/efs/workspace)
   │   └─ Persistent Storage
   │
   └─ Secrets Manager
       └─ LLM API Keys (Shared)
```

## Components

### 1. Networking (VPC)

- **VPC**: `10.0.0.0/16` CIDR block
- **Public Subnets**: 2 subnets across 2 availability zones
- **Internet Gateway**: For public internet access
- **Route Tables**: Routes public traffic through IGW

### 2. Compute (ECS Fargate)

- **Cluster**: `opencode-agent-cluster`
- **Service**: `opencode-agent-service`
- **Task Definition**: 
  - CPU: 1024 (1 vCPU)
  - Memory: 2048 MB (2 GB)
  - Container: OpenCode server on port 4096
- **Scaling**: Currently 1 task, can be scaled horizontally

### 3. Storage (EFS)

- **File System**: Encrypted EFS for persistent storage
- **Access Point**: `/workspace` directory with proper permissions
- **Mount Point**: `/mnt/efs/workspace` in containers
- **Lifecycle**: Transitions to Infrequent Access after 30 days

### 4. Load Balancing (ALB)

- **Type**: Application Load Balancer
- **Port**: 80 (HTTP), 443 (HTTPS optional)
- **Target Group**: Routes to ECS tasks on port 4096
- **Sticky Sessions**: Enabled (24-hour cookie duration)
- **Health Checks**: HTTP GET on `/` every 30 seconds

### 5. Security

- **Secrets Manager**: Stores `ANTHROPIC_API_KEY` and `OPENAI_API_KEY`
- **IAM Roles**:
  - Execution Role: Pulls images, reads secrets, mounts EFS
  - Task Role: For future task-level permissions
- **Security Groups**:
  - ALB: Allows 80/443 from internet
  - ECS: Allows 4096 from ALB only
  - EFS: Allows NFS (2049) from ECS only

### 6. Container Registry (ECR)

- **Repository**: `opencode-agent`
- **Image**: Based on Cloudflare Sandbox with OpenCode installed
- **Lifecycle**: Keeps last 10 images, auto-deletes older ones

### 7. Monitoring

- **CloudWatch Logs**: `/ecs/opencode-agent` (7-day retention)
- **Container Insights**: Enabled on ECS cluster
- **ALB Access Logs**: Can be enabled for request tracking

### 8. Session Management

- **OpenCode Native**: OpenCode manages its own sessions in the workspace directory
- **Sticky Sessions**: ALB ensures users hit the same container instance
- **DynamoDB**: Optional table for session metadata tracking (created but not actively used)

## Data Flow

### Request Flow

1. User opens browser → `http://alb-dns-name`
2. ALB receives request → Checks for sticky session cookie
3. Routes to appropriate ECS task → Port 4096
4. OpenCode container processes request
5. Response sent back through ALB → User

### Session Persistence

- **Workspace Data**: Stored in EFS at `/mnt/efs/workspace`
- **Session Files**: OpenCode creates session files in workspace
- **Sticky Sessions**: ALB cookie ensures same container for 24 hours
- **Container Restart**: Data persists in EFS, new container picks up existing sessions

### API Key Management

- **Storage**: AWS Secrets Manager (encrypted)
- **Access**: ECS execution role has read permissions
- **Injection**: Secrets injected as environment variables at container startup
- **Sharing**: Single set of keys shared across all users/containers

## Scaling Considerations

### Horizontal Scaling

- Increase `desired_count` in ECS service
- ALB distributes load across tasks
- Each task has its own EFS mount (shared filesystem)
- Sticky sessions may limit load distribution

### Vertical Scaling

- Increase CPU/memory in task definition
- Update service to use new task definition
- Useful for larger codebases or more concurrent users

### Cost Optimization

- **Fargate Spot**: Use for non-production (add to task definition)
- **EFS IA**: Already configured (transitions after 30 days)
- **Reserved Capacity**: Consider for predictable workloads
- **Auto Scaling**: Can be added based on CPU/memory metrics

## Security Considerations

### Network Security

- ECS tasks in private subnets (can be configured)
- Security groups restrict traffic flow
- EFS uses transit encryption

### Secrets Security

- API keys never in code or logs
- Secrets Manager encryption at rest
- IAM policies limit access
- Rotation can be configured

### Container Security

- Base image from Cloudflare (trusted source)
- Minimal attack surface
- No root access required (can be configured)

## Disaster Recovery

### Backup Strategy

- **EFS**: Automatic backups via AWS Backup (can be configured)
- **Task Definitions**: Stored in ECS (versioned)
- **Terraform State**: Should be backed up (S3 + DynamoDB)

### Recovery Procedures

1. **Container Failure**: ECS automatically restarts
2. **Service Failure**: Terraform can recreate infrastructure
3. **Data Loss**: Restore from EFS backup (if configured)
4. **Region Failure**: Deploy to another region (multi-region setup)

## Future Enhancements

- [ ] HTTPS/TLS termination
- [ ] Custom domain with Route 53
- [ ] Auto Scaling based on metrics
- [ ] Multi-region deployment
- [ ] CI/CD pipeline
- [ ] Enhanced monitoring and alerting
- [ ] User authentication/authorization
- [ ] Per-user workspace isolation


