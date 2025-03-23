# Terraform Infrastructure for Network Tools Suite

## Current Status

The Terraform infrastructure for the Network Tools Suite is mostly complete with the following components:

- AWS VPC with public subnets across multiple availability zones
- EC2 instances running Amazon Linux 2 with Nginx and multiple Flask applications
- Elastic Load Balancer (Classic) for traffic distribution
- Security groups with proper access controls
- AWS Certificate Manager integration for HTTPS (optional)
- Attractive landing page with links to all three applications

The suite includes three applications:
1. **Workbook Importer** - For importing and processing network workbooks
2. **Workbook Exporter** - For exporting network configurations to standardized formats
3. **Firewall Request Generator** - For generating properly formatted firewall change requests

Recent changes:
- Expanded the infrastructure to host all three applications
- Created an attractive landing page for application selection
- Fixed security group circular dependency using aws_security_group_rule
- Enhanced security by restricting outbound traffic to necessary services
- Configured Nginx to route traffic to the appropriate application

## Next Steps

### Immediate Priorities

1. **Apply Security Configuration**: After fixing the circular dependency in security groups, apply the changes with `terraform apply`.

2. **Configure HTTPS**: Complete HTTPS setup by:
   - Setting a proper domain name in `variables.tf`
   - Setting `enable_https = true`
   - Following the DNS validation procedure in `docs/https_instructions.md`

3. **Test Applications**: Verify all applications are accessible through:
   - Main landing page: http://[load_balancer_dns]/
   - Workbook Importer: http://[load_balancer_dns]/importer
   - Workbook Exporter: http://[load_balancer_dns]/exporter
   - Firewall Request Generator: http://[load_balancer_dns]/firewall
   - Health check: http://[load_balancer_dns]/health

### Recommended Improvements

Based on best practices analysis, consider implementing these improvements:

#### Security Enhancements:
- Set AWS provider version constraints in main.tf
- Ensure `management_ip` is properly set to a specific IP address
- Enable EBS volume encryption for EC2 instances
- Enforce IMDSv2 for EC2 instances to prevent SSRF attacks
- Further restrict ELB egress rules
- Add WAF for application-layer protection

#### Resilience Improvements:
- Implement auto-scaling groups for EC2 instances
- Add health checks with proper thresholds
- Configure CloudWatch alarms for critical metrics
- Implement a backup solution for application data
- Add error handling in user_data.sh

#### Operational Enhancements:
- Set up centralized logging with CloudWatch Logs
- Implement proper tagging strategy
- Use data sources for AMI IDs to keep them updated
- Implement remote state management
- Add IAM roles for EC2 instances instead of hardcoded credentials

## Terraform Commands

Run these commands from within the project directory:

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan -var 'management_ip=YOUR_IP_ADDRESS'

# Apply changes
terraform apply -var 'management_ip=YOUR_IP_ADDRESS'

# Destroy infrastructure (when done)
terraform destroy -var 'management_ip=YOUR_IP_ADDRESS'
```

## Troubleshooting

If you encounter issues:
- Check instance health with SSH: `ssh ec2-user@[instance_public_ip]`
- Run diagnostic script: `sudo /opt/check_services.sh`
- View logs: `sudo journalctl -u flask_app.service` and `sudo cat /var/log/nginx/flask_error.log`
- Refer to detailed troubleshooting guide in `docs/troubleshooting.md`