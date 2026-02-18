resource "aws_secretsmanager_secret" "llm_keys" {
  name        = "${var.project_name}-llm-keys"
  description = "LLM provider API keys for OpenCode agent"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-llm-keys"
  })

  lifecycle {
    ignore_changes = [name]
  }
}

resource "aws_secretsmanager_secret_version" "llm_keys" {
  secret_id = aws_secretsmanager_secret.llm_keys.id
  secret_string = jsonencode({
    ANTHROPIC_API_KEY = var.anthropic_api_key != "" ? var.anthropic_api_key : "CHANGE_ME"
    OPENAI_API_KEY    = var.openai_api_key != "" ? var.openai_api_key : "CHANGE_ME"
  })
}


