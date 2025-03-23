# CLAUDE.md - Terraform Web Server Project

## Commands
- `terraform init`: Initialize Terraform working directory
- `terraform validate`: Validate Terraform configuration
- `terraform fmt`: Format Terraform code
- `terraform plan`: Preview changes before applying
- `terraform apply`: Apply Terraform configuration
- `terraform destroy`: Destroy provisioned infrastructure
- `tflint`: Lint Terraform code (if installed)

## Code Style Guidelines
- **Terraform Version**: Use HCL (HashiCorp Configuration Language) syntax
- **Formatting**: Use 2-space indentation, run `terraform fmt` before commits
- **Naming Conventions**:
  - Resources: `snake_case` (e.g., `aws_security_group`)
  - Variables: Descriptive names with `snake_case`
  - Tags: CamelCase for AWS resource tags
- **Resource Structure**: Group related resources in separate `.tf` files
- **Variable Types**: Always specify type constraints for variables
- **Error Handling**: Use `count` or `for_each` conditionals for error cases
- **Documentation**: Comment complex expressions and resource purposes
- **String Interpolation**: Use `${}` syntax consistently for variables
- **Security Best Practices**: Avoid hardcoding sensitive data, use variables