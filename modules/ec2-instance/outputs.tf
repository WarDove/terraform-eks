output "URL" {
  description = "URL of the endpoint"
  value       = var.tls_termination ? "https://${var.subdomain}.${data.aws_route53_zone.main[0].name}" : "http://${var.subdomain}.${data.aws_route53_zone.main[0].name}"
}