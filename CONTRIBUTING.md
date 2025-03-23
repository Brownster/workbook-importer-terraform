# Contributing to Workbook Importer Terraform

Thank you for considering contributing to the Workbook Importer Terraform project! This document provides guidelines and instructions for contributing.

## Development Process

1. Fork the repository
2. Create a new branch for your feature or bugfix
3. Make your changes
4. Submit a pull request

## Terraform Style Guide

When contributing to this project, please follow these Terraform style guidelines:

- Use 2-space indentation
- Align `=` for variable and output blocks
- Use snake_case for resource naming
- Always include descriptive comments for complex logic
- Include meaningful tag values for AWS resources

Example:
```hcl
resource "aws_instance" "web" {
  count           = var.instance_count
  ami             = lookup(var.ami_ids, var.region)
  instance_type   = var.instance_type
  subnet_id       = element(aws_subnet.public.*.id, count.index)
  
  # User data script for application installation
  user_data       = file("scripts/bootstrap.sh")
  
  tags = {
    Name          = "${var.app_name}-server-${count.index + 1}"
    Environment   = var.environment
    ManagedBy     = "Terraform"
  }
}
```

## Testing Changes

Before submitting your pull request, please test your changes:

1. Run `terraform fmt` to format your code
2. Run `terraform validate` to check for syntax errors
3. Run `terraform plan` to verify that your changes produce the expected resources

## Documentation

When adding new features or making significant changes, update the documentation:

- Update the README.md if necessary
- Add information to the architecture documentation if you're changing the infrastructure design
- Update the troubleshooting guide if your changes impact the operational aspects

## Submitting Pull Requests

When submitting a pull request:

1. Include a clear description of the changes
2. Reference any related issues
3. Include screenshots or diagrams for UI or architectural changes
4. Check that all tests pass
5. Ensure documentation is updated

## Getting Help

If you need help with contributing, open an issue with the "question" label, and we'll be happy to assist you.