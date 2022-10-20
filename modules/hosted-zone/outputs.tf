# This output depends on certificate validation, to make sure that arn is shared after validation"
output "certificate_arn" {
  depends_on = [
    aws_acm_certificate_validation.cert_validation
  ]
  value = join("", aws_acm_certificate.main[*].arn)
}

output "zone_id" {
  value = local.zone_id
}
