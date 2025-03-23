#!/bin/bash

# Enable detailed logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution at $(date)"

# Update system packages - Amazon Linux 2 uses yum
yum update -y
yum install -y python3 python3-pip git

# Install nginx from Amazon Linux extras
amazon-linux-extras install -y nginx1
systemctl start nginx
systemctl enable nginx

# Create directory for application
mkdir -p /opt/workbook_importer
cd /opt/workbook_importer

# Create a simple health check page for the load balancer
mkdir -p /usr/share/nginx/html
cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Workbook Importer - Health Check</title>
</head>
<body>
    <h1>Workbook Importer Application is Running</h1>
    <p>This is a health check page for the load balancer.</p>
</body>
</html>
EOF

# Clone the repository
echo "Cloning the repository"
git clone https://github.com/Brownster/workbook_importer.git /opt/workbook_importer

# Install Python dependencies
echo "Installing Python dependencies"
pip3 install -r requirements.txt

# Create debugging info to check Flask app
cat > /opt/workbook_importer/debug_app.py <<'EOF'
import sys
import os

print("Python version:", sys.version)
print("Working directory:", os.getcwd())
print("Directory contents:", os.listdir())
if os.path.exists("app.py"):
    with open("app.py", "r") as f:
        print("First 10 lines of app.py:")
        for i, line in enumerate(f):
            if i < 10:
                print(f"{i+1}: {line.strip()}")
else:
    print("app.py does not exist!")
EOF

# Execute the debug script and save to log
python3 /opt/workbook_importer/debug_app.py > /opt/workbook_importer/debug_output.log

# Configure Nginx as a reverse proxy
cat > /etc/nginx/conf.d/flask_app.conf <<'EOF'
server {
    listen 80;
    server_name _;

    # For health checks
    location = / {
        root /usr/share/nginx/html;
        index index.html;
    }

    # Forward all other requests to the Flask application
    location / {
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

# Remove default configuration if it exists
rm -f /etc/nginx/conf.d/default.conf

# Apply Nginx settings
echo "Restarting Nginx"
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
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=FLASK_ENV=production
Environment=FLASK_APP=app.py

[Install]
WantedBy=multi-user.target
EOF

# Fix permissions
chown -R ec2-user:ec2-user /opt/workbook_importer

# Enable and start the Flask service
echo "Starting Flask application service"
systemctl daemon-reload
systemctl enable flask_app.service
systemctl start flask_app.service

# Check service status and log it
systemctl status flask_app.service > /opt/workbook_importer/service_status.log

# Create instance info file
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
echo "Instance $INSTANCE_ID in $REGION is running the Workbook Importer application" > /opt/workbook_importer/instance_info.txt

# Log completion of user data script
echo "User data script completed at $(date)"