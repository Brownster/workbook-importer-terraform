# HTTPS Configuration for Workbook Importer

This guide explains how to enable HTTPS for your Workbook Importer application using AWS Certificate Manager (ACM) and Terraform.

## Prerequisites

1. A registered domain name
2. DNS management access to create validation records
3. AWS account with permissions to create ACM certificates

## Enabling HTTPS

### 1. Configure Variables

Edit the `variables.tf` file and set the following variables:

```hcl
variable "domain_name" {
  description = "Domain name for the application (required for HTTPS)"
  default     = "your-domain.com"  # Replace with your domain
}

variable "enable_https" {
  description = "Whether to enable HTTPS using ACM"
  type        = bool
  default     = true
}
```

### 2. Apply Configuration

Run Terraform to apply the changes:

```bash
terraform apply
```

### 3. Validate Certificate

After applying, Terraform will output certificate validation records:

```
certificate_validation_domains = {
  "your-domain.com" = {
    name   = "_abcdef1234.your-domain.com"
    record = "5678ghijklmno..."
    type   = "CNAME"
  }
}
```

Create these DNS records with your DNS provider:
- Create a CNAME record with the provided name
- Set the value to the provided record
- Wait for DNS propagation (can take 15-30 minutes)

### 4. Check Certificate Status

Check the status of your certificate:

```bash
aws acm describe-certificate --certificate-arn <certificate_arn_from_output>
```

Wait until the status shows as "ISSUED".

### 5. Complete Deployment

Once the certificate is validated, run Terraform again to complete the deployment:

```bash
terraform apply
```

## Accessing via HTTPS

After successful deployment, you can access your application via HTTPS:

- Main URL: `https://your-domain.com/`
- Application: `https://your-domain.com/app`

## Troubleshooting

### Certificate Validation Issues

If certificate validation fails:
- Verify DNS records are correctly set
- Check for typos in domain name
- Ensure DNS propagation has completed

### HTTPS Connection Issues

If you cannot connect via HTTPS:
- Check security group rules for port 443
- Verify load balancer listener is correctly configured
- Confirm certificate is in "ISSUED" state

## Automatic Renewal

AWS Certificate Manager automatically renews certificates before expiry. However:

1. Ensure DNS validation records remain in place
2. Monitor certificate status regularly