locals {
  private_hosted_zone = length(var.vpc_id) > 0
  zone_id             = var.created_manually ? data.aws_route53_zone.main.*.id[0] : resource.aws_route53_zone.main.*.id[0]
}

data "aws_route53_zone" "main" {
  count        = var.created_manually ? 1 : 0
  name         = var.dns_zone
  private_zone = false
}

resource "aws_route53_zone" "main" {
  count = var.created_manually ? 0 : 1
  name  = var.dns_zone

  dynamic "vpc" {
    for_each = local.private_hosted_zone ? [1] : []

    content {
      vpc_id = aws_vpc.example.id
    }
  }
}

resource "aws_acm_certificate" "main" {
  count                     = var.tls_termination ? 1 : 0
  domain_name               = var.dns_zone
  subject_alternative_names = ["*.${var.dns_zone}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.tls_termination ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
  } } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  count                   = var.tls_termination ? 1 : 0
  certificate_arn         = aws_acm_certificate.main.*.arn[0]
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


