locals {
  validation_domains = toset(distinct(concat([var.domain_name], var.subject_alternative_names)))
  validation_records = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = trimsuffix(dvo.resource_record_name, ".")
      record = trimsuffix(dvo.resource_record_value, ".")
      type   = dvo.resource_record_type
    }
  }
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "cloudflare_dns_record" "validation" {
  for_each = local.validation_domains

  zone_id = var.zone_id
  name    = local.validation_records[each.value].name
  content = local.validation_records[each.value].record
  type    = local.validation_records[each.value].type
  ttl     = 1
  proxied = false
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn

  validation_record_fqdns = [
    for record in cloudflare_dns_record.validation : record.name
  ]
}
