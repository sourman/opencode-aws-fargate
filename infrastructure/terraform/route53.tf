data "aws_route53_zone" "main" {
  count        = var.create_hosted_zone ? 0 : 1
  name         = "compliancy-csm.xyz."
  private_zone = false
}

resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0
  name  = "compliancy-csm.xyz"

  tags = merge(local.common_tags, {
    Name = "compliancy-csm.xyz"
  })
}

locals {
  zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.main[0].zone_id
  zone_name_servers = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : null
}

resource "aws_route53_record" "agent" {
  zone_id = local.zone_id
  name    = "agent.compliancy-csm.xyz"
  type    = "A"
  ttl     = 60

  records = ["127.0.0.1"]
}

output "route53_dns_name" {
  description = "DNS name for accessing OpenCode"
  value       = aws_route53_record.agent.fqdn
}

output "name_servers" {
  description = "Name servers for the hosted zone (if created). Update your domain registrar with these if needed."
  value       = local.zone_name_servers
}

