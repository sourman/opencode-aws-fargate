variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "opencode-agent"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "enable_https" {
  description = "Enable HTTPS listener"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS"
  type        = string
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "create_hosted_zone" {
  description = "Create Route53 hosted zone if it doesn't exist"
  type        = bool
  default     = false
}



