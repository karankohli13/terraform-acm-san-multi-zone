// Create the certificate
resource "aws_acm_certificate" "cert" {
  domain_name               = var.primary_domain.domain
  validation_method         = "DNS"
  subject_alternative_names = keys(var.subject_alternative_names)
  // Many things depend on a certificate, so create a new one for them to switch to before deleting this one
  lifecycle {
    create_before_destroy = true
  }
}

// Create a record in Route53 for validating each domain on the certificate
resource "aws_route53_record" "cert-validation" {
  // Create a custom mapping so changes in list ordering don't re-create the resource
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
    if lookup(var.subject_alternative_names, dvo.domain_name, null) != null
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id = each.key == var.primary_domain.domain ? var.primary_domain.hosted_zone_id : lookup(var.subject_alternative_names, each.key, var.primary_domain.hosted_zone_id)
}

// Validate the certificate
resource "aws_acm_certificate_validation" "cert" {
  count = var.wait_for_validation ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert-validation : record.fqdn]
}