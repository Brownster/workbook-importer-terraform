# AWS Certificate Manager resources for HTTPS
# Only created when enable_https = true and domain_name is provided

# Request an SSL certificate
resource "aws_acm_certificate" "cert" {
  count             = var.enable_https && var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"
  
  # Support both www and apex domain
  subject_alternative_names = ["*.${var.domain_name}"]
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name    = "${var.app_name}-certificate"
    Domain  = var.domain_name
    Created = "Terraform"
  }
}

# Output validation details for DNS verification
output "certificate_validation_domains" {
  description = "DNS records to create for certificate validation"
  value       = var.enable_https && var.domain_name != "" ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
}

# Wait for DNS validation
resource "aws_acm_certificate_validation" "cert_validation" {
  count                   = var.enable_https && var.domain_name != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  
  # Comment out this line if you can't create DNS records automatically
  # and manually validate the certificate
  # validation_record_fqdns  = [for record in aws_route53_record.cert_validation : record.fqdn]

  # Increase timeout to allow for DNS propagation
  timeouts {
    create = "60m"
  }
}