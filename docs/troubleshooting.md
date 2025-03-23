# Troubleshooting Guide

This guide provides solutions for common issues you might encounter with the Workbook Importer infrastructure.

## Application Not Accessible

If you cannot access the application via the load balancer or instance directly:

### Check Instance Health

1. Verify EC2 instance status in AWS Console
2. SSH into the instance: `ssh ec2-user@[instance-public-ip]`
3. Check the automatic diagnostic report:
   ```bash
   sudo cat /opt/service_check_results.log
   ```

### Verify Services Running

Check if Nginx and all application services are running:
```bash
sudo systemctl status nginx
sudo systemctl status workbook_importer.service
sudo systemctl status workbook_exporter.service
sudo systemctl status firewall_generator.service
```

If any service is not running, try restarting it:
```bash
sudo systemctl restart nginx
sudo systemctl restart workbook_importer.service
sudo systemctl restart workbook_exporter.service
sudo systemctl restart firewall_generator.service
```

You can also check all services at once using the provided script:
```bash
sudo /opt/check_services.sh
```

### Check Logs for Errors

View Nginx error logs:
```bash
sudo cat /var/log/nginx/flask_error.log
```

View application logs:
```bash
# Workbook Importer logs
sudo journalctl -u workbook_importer.service

# Workbook Exporter logs
sudo journalctl -u workbook_exporter.service

# Firewall Request Generator logs
sudo journalctl -u firewall_generator.service
```

Check user data script execution logs:
```bash
sudo cat /var/log/user-data.log
```

### Verify Network Connectivity

Test network connectivity on the instance:
```bash
# Check listening ports for all applications
sudo netstat -tulpn | grep -E ':(80|5001|5002|5003)'

# Test local access
curl http://localhost/                 # Main landing page
curl http://localhost/importer         # Workbook Importer
curl http://localhost/exporter         # Workbook Exporter
curl http://localhost/firewall         # Firewall Request Generator
curl http://localhost/health           # Health check endpoint
```

### Check Security Groups

Verify security group rules allow:
- Port 80 inbound from anywhere (for HTTP)
- Port 443 inbound if HTTPS is enabled
- Port 22 inbound from your management IP only (for SSH access)

## Load Balancer Issues

If the load balancer shows instances as unhealthy:

1. Check the health check configuration in the AWS Console
2. Verify the health check endpoint is accessible on the instances
3. Test the health check path directly:
   ```bash
   curl http://[instance-public-ip]/
   ```

## Application Errors

If the application loads but shows errors:

1. Check Flask application error logs:
   ```bash
   sudo journalctl -u flask_app.service -n 50
   ```

2. Check if Python dependencies are installed correctly:
   ```bash
   cd /opt/workbook_importer
   pip3 list
   ```

3. Verify application files ownership:
   ```bash
   ls -la /opt/workbook_importer
   ```

## Additional Resources

For more advanced troubleshooting:

1. Run the complete diagnostics script:
   ```bash
   sudo /opt/check_services.sh
   ```

2. Check instance metadata:
   ```bash
   curl http://169.254.169.254/latest/meta-data/instance-id
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```

3. Check cloud-init logs:
   ```bash
   sudo cat /var/log/cloud-init-output.log
   ```