# Network Tools Suite AWS Terraform Infrastructure

This repository contains Terraform configuration to deploy a suite of network management tools on AWS EC2 instances behind a load balancer in the London (eu-west-2) region. The suite includes:

1. [Workbook Importer](https://github.com/Brownster/workbook_importer) - Import and process network workbooks
2. [Workbook Exporter](https://github.com/Brownster/workbook_exporter) - Export network configurations to standardized workbooks
3. [Firewall Request Generator](https://github.com/Brownster/portmapper) - Generate properly formatted firewall change requests

## Architecture

![Architecture Diagram](https://github.com/Brownster/workbook-importer-terraform/raw/main/docs/architecture.png)

- **VPC**: Isolated network environment with CIDR 192.168.100.0/24
- **Subnets**: 
  - 2 private subnets for application instances
  - 2 public subnets for load balancer and internet access
- **EC2 Instances**: Amazon Linux 2 running Python/Flask and Nginx
- **Elastic Load Balancer**: Distributes traffic across instances
- **Security Groups**: Controlled access to resources
- **Internet Gateway**: Enables internet connectivity

## Deployment Process

Upon deployment, the infrastructure automatically:
1. Provisions networking components (VPC, subnets, routing)
2. Creates EC2 instances with Amazon Linux 2
3. Installs and configures Nginx, Python, wkhtmltopdf, and dependencies
4. Clones all application repositories:
   - Workbook Importer
   - Workbook Exporter
   - Firewall Request Generator
5. Configures each application as a systemd service
6. Sets up a central landing page with links to all applications
7. Configures Nginx as a reverse proxy to route traffic to each application
8. Sets up load balancing with health checks

## Requirements

- [Terraform](https://www.terraform.io/downloads.html) 0.12+
- AWS credentials configured with appropriate permissions
- Git (for cloning this repository)
- Your IP address for management access

## Deployment Instructions

1. Clone this repository:
   ```bash
   git clone https://github.com/Brownster/workbook-importer-terraform.git
   cd workbook-importer-terraform
   ```

2. Set your management IP in variables.tf:
   ```bash
   # Edit the management_ip variable with your IP address
   # Example: default = "203.0.113.1"
   ```

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Review the execution plan:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

6. After successful deployment (which may take 5-10 minutes), the following outputs will be displayed:
   - `application_url`: URL to access the application
   - `load_balancer_dns`: DNS name of the load balancer
   - `public_ips`: Public IP addresses of the EC2 instances

## Accessing the Applications

You can access all applications through the load balancer:

- **Main landing page**: http://[load_balancer_dns]/
- **Workbook Importer**: http://[load_balancer_dns]/importer
- **Workbook Exporter**: http://[load_balancer_dns]/exporter
- **Firewall Request Generator**: http://[load_balancer_dns]/firewall
- **Health check endpoint**: http://[load_balancer_dns]/health
- **Server information**: http://[load_balancer_dns]/info.html

If you need to access the instance directly (restricted to your management IP):

- **SSH access**: `ssh ec2-user@[instance_public_ip]`

## Troubleshooting

If you encounter issues accessing the application:

1. **Verify Instance Status**: 
   ```bash
   ssh ec2-user@[instance_public_ip]
   sudo cat /opt/service_check_results.log
   ```

2. **Check Service Status**:
   ```bash
   sudo systemctl status nginx
   sudo systemctl status flask_app.service
   ```

3. **View Error Logs**:
   ```bash
   sudo cat /var/log/nginx/flask_error.log
   sudo journalctl -u flask_app.service
   ```

4. **Run Diagnostic Script**:
   ```bash
   sudo /opt/check_services.sh
   ```

## Customization

### Configuration Variables

The main configuration variables are defined in `variables.tf`. You can customize:

- `instance_count`: Number of EC2 instances (default: 2)
- `instance_type`: EC2 instance type (default: t2.micro)
- `app_name`: Application name (default: workbook-importer)
- `network_cidr`: VPC CIDR block (default: 192.168.100.0/24)
- `availability_zones`: AZs to deploy into (default: eu-west-2a, eu-west-2b)
- `management_ip`: Your IP address for SSH access (REQUIRED)

### Adding SSL/TLS

To enable HTTPS:

1. Provision an SSL certificate in AWS Certificate Manager (ACM)
2. Update the load balancer configuration to use the certificate
3. Add a listener for HTTPS (port 443)

Example addition to `load_balancer.tf`:

```hcl
listener {
  instance_port      = 80
  instance_protocol  = "http"
  lb_port            = 443
  lb_protocol        = "https"
  ssl_certificate_id = "arn:aws:acm:eu-west-2:YOUR_ACCOUNT_ID:certificate/YOUR_CERT_ID"
}
```

## Security Considerations

- **SSH Access**: SSH access is strictly limited to your management IP address. You MUST set your IP in the `management_ip` variable before deploying.
- **Restricted Traffic**: Only necessary outbound traffic is allowed:
  - HTTPS to GitHub repositories
  - HTTP/HTTPS for package repositories
  - DNS and NTP for essential services
- **Internal Flask Application**: The Flask app is only accessible through the load balancer, not directly
- **HTTPS**: For production, enable HTTPS using AWS Certificate Manager (see docs/https_instructions.md)
- **Enhanced EC2 Security**:
  - IMDSv2 required to prevent SSRF attacks
  - EBS volumes encrypted at rest
  - Restricted network access
- **Load Balancer Security**: ELB's outbound traffic is restricted to only necessary connections
- **Future Improvements**: See docs/improvement_plan.md for planned security enhancements

## Maintenance

### Updating the Application

To update the Workbook Importer application:

1. Update the repository URL in `user_data.sh` if needed
2. Run `terraform apply` to deploy the changes

### Scaling

To adjust capacity:

1. Modify the `instance_count` variable
2. Run `terraform apply` to apply changes

## Clean Up

To remove all resources created by Terraform:

```bash
terraform destroy
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.