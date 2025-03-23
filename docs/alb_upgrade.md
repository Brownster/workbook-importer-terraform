# Application Load Balancer Upgrade

## Changes Made

1. **Converted from Classic ELB to Application Load Balancer (ALB)**
   - Implemented modern ALB for improved path-based routing
   - Configured HTTP health check on `/health` path
   - Updated listeners for both HTTP and HTTPS
   - Created proper target group for instance registration

2. **Security Improvements**
   - Configured SSH access for both management IP and AWS EC2 Instance Connect
   - Maintained security group rules for proper separation
   - Updated security group references

3. **Nginx Configuration Improvements**
   - Proper proxy configuration for each application
   - Added fallback static pages for application startup period
   - Proper error handling for backend connection issues
   - Improved logging for troubleshooting

4. **Systemd Service Configuration**
   - Configured proper system services for the three applications
   - Set correct ports for each application (5001, 5002, 5003)
   - Added proper restart and error handling
   - Configured Flask environment variables

## Next Steps

1. **Apply the changes**
   ```bash
   terraform apply -var 'management_ip=YOUR_IP_ADDRESS'
   ```

2. **Test the application paths**
   - Main landing page: http://[load_balancer_dns]/
   - Workbook Importer: http://[load_balancer_dns]/importer
   - Workbook Exporter: http://[load_balancer_dns]/exporter
   - Firewall Request Generator: http://[load_balancer_dns]/firewall
   - Health check: http://[load_balancer_dns]/health
   - Server info: http://[load_balancer_dns]/info.html

3. **Verify health checks are passing**
   - Check ALB target health in AWS Console
   - Ensure targets are reported as healthy

4. **Access instances via SSH if needed**
   - Use AWS Console EC2 Instance Connect
   - Alternatively, connect from management IP
   - Run `/opt/check_services.sh` for diagnostics

5. **Review logs if issues persist**
   - `/var/log/user-data.log` - User data script execution
   - `/var/log/instance-setup.log` - Detailed setup information
   - `/var/log/nginx/apps_error.log` - Nginx error log
   - `/var/log/nginx/apps_access.log` - Nginx access log

6. **Setup HTTPS**
   - Set `domain_name` variable to your domain
   - Set `enable_https = true`
   - Complete certificate validation