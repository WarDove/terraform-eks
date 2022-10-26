# Must be noted that if alb is set to "none" and subnet_type
# is set to "private" setting both subdomain and hosted_zone_id
# Will trigger an error, but if subnet_type is set to be public
# dns record will be created for elastic ip of the instance
# without tls_termination
data "aws_route53_zone" "main" {
  count   = var.hosted_zone_id != "none" ? 1 : 0
  zone_id = var.hosted_zone_id

  lifecycle {

    precondition {
      condition     = var.subdomain != "none" || var.registry_subdomain != "none"
      error_message = "subdomain is not set!"
    }
    # IF no ALB is created and no EIP created for instance - which
    # would mean that this is a private instance with no load balancer and
    # if the dns zone is not a private zone then error must be triggered
    postcondition {
      condition     = var.alb || local.allocate_eip
      error_message = "Private instance shouldn't have a record in a public dns zone!"
    }
  }
}

data "aws_route53_zone" "internal" {
  count   = var.internal_hosted_zone_id != "none" ? 1 : 0
  zone_id = var.internal_hosted_zone_id

  lifecycle {

    precondition {
      condition     = var.subdomain != "none" || var.registry_subdomain != "none"
      error_message = "subdomain is not set!"
    }
    # IF no internal ALB is created and the indicated hosed zone is not private error will be triggered
    postcondition {
      condition     = self.private_zone
      error_message = "Please set only private hosted zone id as input for internal_alb_hosted_zone_id"
    }
  }
}

# Record for instance subdomain
resource "aws_route53_record" "alb_record" {
  count   = var.subdomain != "none" && var.alb && var.hosted_zone_id != "none" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "${var.subdomain}.${data.aws_route53_zone.main[0].name}"
  type    = "A"

  alias {
    name                   = aws_lb.main[0].dns_name
    zone_id                = aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "alb_record_internal" {
  count   = var.subdomain != "none" && var.internal_alb && var.internal_hosted_zone_id != "none" ? 1 : 0
  zone_id = data.aws_route53_zone.internal[0].zone_id
  name    = "${var.subdomain}.${data.aws_route53_zone.internal[0].name}"
  type    = "A"

  alias {
    name                   = aws_lb.internal[0].dns_name
    zone_id                = aws_lb.internal[0].zone_id
    evaluate_target_health = true
  }
}

# Record for docker registry subdomain
resource "aws_route53_record" "alb_record_docker" {
  count   = var.registry_subdomain != "none" && var.alb && var.hosted_zone_id != "none" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "${var.registry_subdomain}.${data.aws_route53_zone.main[0].name}"
  type    = "A"

  alias {
    name                   = aws_lb.main[0].dns_name
    zone_id                = aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "alb_record_docker_internal" {
  count   = var.registry_subdomain != "none" && var.internal_alb && var.internal_hosted_zone_id != "none" ? 1 : 0
  zone_id = data.aws_route53_zone.internal[0].zone_id
  name    = "${var.registry_subdomain}.${data.aws_route53_zone.internal[0].name}"
  type    = "A"

  alias {
    name                   = aws_lb.internal[0].dns_name
    zone_id                = aws_lb.internal[0].zone_id
    evaluate_target_health = true
  }
}

# Instance record for eip in case if public instance has no alb
resource "aws_route53_record" "eip_record" {
  count   = var.subdomain != "none" && local.allocate_eip ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "${var.subdomain}.${data.aws_route53_zone.main[0].name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.instance_eip[0].public_ip]
}

# Docker registry record for eip in case if public instance has no alb
resource "aws_route53_record" "eip_record_docker" {
  count   = var.registry_subdomain != "none" && local.allocate_eip ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "${var.registry_subdomain}.${data.aws_route53_zone.main[0].name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.instance_eip[0].public_ip]
}


# Instance record for private ip in case if private instance has no internal_alb
resource "aws_route53_record" "private_ip_record" {
  count   = var.subdomain != "none" && local.allocate_private_ip && var.internal_hosted_zone_id != "none" ? 1 : 0
  zone_id = data.aws_route53_zone.internal[0].zone_id
  name    = "${var.subdomain}.${data.aws_route53_zone.internal[0].name}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.main.private_ip]
}

# Docker registry record for private ip in case if private instance has no internal_alb
resource "aws_route53_record" "private_ip_record_docker" {
  count   = var.registry_subdomain != "none" && local.allocate_private_ip && var.internal_hosted_zone_id != "none" ? 1 : 0
  zone_id = data.aws_route53_zone.internal[0].zone_id
  name    = "${var.registry_subdomain}.${data.aws_route53_zone.internal[0].name}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.main.private_ip]
}



# TODO: Create logic for apex domain as well i.e if subdomain == "apex"