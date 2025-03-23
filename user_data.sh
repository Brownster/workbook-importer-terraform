#!/bin/bash

# Update system packages - Amazon Linux 2 uses yum, not apt
yum update -y

# Install required packages
yum install -y python3 python3-pip git

# Install nginx from Amazon Linux extras
amazon-linux-extras install -y nginx1

# Start nginx
systemctl start nginx
systemctl enable nginx

# Create directory for application
mkdir -p /opt/workbook_importer

# Clone the repository
git clone https://github.com/Brownster/workbook_importer.git /opt/workbook_importer

# Change to application directory
cd /opt/workbook_importer

# Install dependencies
pip3 install -r requirements.txt

# Configure Nginx as a reverse proxy
cat > /etc/nginx/conf.d/flask_app.conf <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Remove default configuration if it exists
rm -f /etc/nginx/conf.d/default.conf

# Restart Nginx
systemctl restart nginx

# Create a systemd service for the Flask app
cat > /etc/systemd/system/flask_app.service <<'EOF'
[Unit]
Description=Workbook Importer Flask App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/opt/workbook_importer
ExecStart=/usr/bin/python3 app.py
Restart=always
Environment=FLASK_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# Fix permissions
chown -R ec2-user:ec2-user /opt/workbook_importer

# Enable and start the service
systemctl daemon-reload
systemctl enable flask_app.service
systemctl start flask_app.service

# Get instance metadata for status page
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
echo "Instance $INSTANCE_ID in $REGION is running the Workbook Importer application" > /opt/workbook_importer/instance_info.txt