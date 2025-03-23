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
echo "Creating application directory"
mkdir -p /opt/workbook_importer

# Create a simple health check page for Nginx
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
    <p>To access the Flask application, go to <a href="/app">/app</a>.</p>
</body>
</html>
EOF

# Clone the repository
echo "Cloning the repository"
git clone https://github.com/Brownster/workbook_importer.git /opt/workbook_importer

# Change to app directory for setup
cd /opt/workbook_importer

# Check what files are available
echo "Checking repository contents:"
ls -la

# Install Python dependencies
echo "Installing Python dependencies"
pip3 install -r requirements.txt

# Create a simple Flask test app just to verify connectivity
cat > /opt/workbook_importer/test_app.py <<'EOF'
from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return '<h1>Flask Test App is Working!</h1><p>This confirms the server can run Flask applications.</p>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
EOF

# Configure Nginx as a reverse proxy
cat > /etc/nginx/conf.d/flask_app.conf <<'EOF'
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/flask_access.log;
    error_log /var/log/nginx/flask_error.log;

    # For health checks and static content
    location = / {
        root /usr/share/nginx/html;
        index index.html;
    }

    # Forward requests to the Flask application with /app prefix
    location /app {
        proxy_pass http://127.0.0.1:5001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Alternative route direct to app root
    location = /test {
        proxy_pass http://127.0.0.1:5001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Remove default configuration if it exists
rm -f /etc/nginx/conf.d/default.conf

# Apply Nginx settings
echo "Restarting Nginx"
systemctl restart nginx

# Create a systemd service for the test Flask app
cat > /etc/systemd/system/flask_app.service <<'EOF'
[Unit]
Description=Test Flask App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/opt/workbook_importer
ExecStart=/usr/bin/python3 test_app.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=FLASK_APP=test_app.py

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

# Create a script to check service status
cat > /opt/check_services.sh <<'EOF'
#!/bin/bash
echo "=== Nginx Status ==="
systemctl status nginx
echo
echo "=== Flask App Status ==="
systemctl status flask_app.service
echo
echo "=== Nginx Configuration Test ==="
nginx -t
echo
echo "=== Network Ports Listening ==="
netstat -tulpn | grep -E ':(80|5001)'
echo
echo "=== Curl test to localhost ==="
curl -v http://localhost/
echo
echo "=== Curl test to Flask app ==="
curl -v http://localhost:5001/
echo
echo "=== Routing test ===" 
curl -v http://localhost/app
EOF

# Make the script executable
chmod +x /opt/check_services.sh

# Run the check script and save output
/opt/check_services.sh > /opt/service_check_results.log 2>&1

# Create instance info file
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Instance Information:" > /usr/share/nginx/html/info.html
echo "<pre>" >> /usr/share/nginx/html/info.html
echo "Instance ID: $INSTANCE_ID" >> /usr/share/nginx/html/info.html
echo "Region: $REGION" >> /usr/share/nginx/html/info.html
echo "Private IP: $PRIVATE_IP" >> /usr/share/nginx/html/info.html
echo "Public IP: $PUBLIC_IP" >> /usr/share/nginx/html/info.html
echo "</pre>" >> /usr/share/nginx/html/info.html

# Log completion of user data script
echo "User data script completed at $(date)"