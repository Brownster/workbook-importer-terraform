#!/bin/bash

# Enable detailed logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution at $(date)"

# Update system packages - Amazon Linux 2 uses yum
yum update -y
yum install -y python3 python3-pip git

# Install dependencies
amazon-linux-extras install -y epel nginx1
yum install -y wkhtmltopdf telnet nc

# Create directory structure
mkdir -p /usr/share/nginx/html /opt/workbook_importer /opt/workbook_exporter /opt/firewall_generator /opt/logs

# Clone repositories
git clone https://github.com/Brownster/workbook_importer.git /opt/workbook_importer
git clone https://github.com/Brownster/workbook_exporter.git /opt/workbook_exporter
git clone https://github.com/Brownster/portmapper.git /opt/firewall_generator

# Download the full configuration script from GitHub
cd /opt
wget https://raw.githubusercontent.com/Brownster/workbook-importer-terraform/main/scripts/configure_services.sh
chmod +x configure_services.sh
./configure_services.sh

# Set proper permissions
chown -R ec2-user:ec2-user /opt/workbook_importer /opt/workbook_exporter /opt/firewall_generator

# Log completion of user data script
echo "User data script completed at $(date)"