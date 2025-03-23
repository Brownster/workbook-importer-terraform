#!/bin/bash

# Enable detailed logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution at $(date)"

# Update system packages - Amazon Linux 2 uses yum
yum update -y
yum install -y python3 python3-pip git

# Install nginx from Amazon Linux extras
echo "Installing Nginx"
amazon-linux-extras install -y nginx1

# Install troubleshooting tools
yum install -y telnet nc

# Stop Nginx to make configuration changes
systemctl stop nginx

# IMPORTANT: Remove default configuration files that might conflict
echo "Removing default Nginx configurations"
rm -f /etc/nginx/conf.d/default.conf
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

# Create a clean main nginx.conf
cat > /etc/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF

# Create webroot directory for Nginx
mkdir -p /usr/share/nginx/html

# Create a simple health check page for Nginx
cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Workbook Importer - Health Check</title>
</head>
<body>
    <h1>Workbook Importer Application is Running</h1>
    <p>This is a health check page for the load balancer.</p>
    <p>To access the Workbook Importer application, go to <a href="/app">/app</a>.</p>
</body>
</html>
EOF

# Create directory for application
echo "Creating application directory"
mkdir -p /opt/workbook_importer

# Clone the repository
echo "Cloning the Workbook Importer repository"
git clone https://github.com/Brownster/workbook_importer.git /opt/workbook_importer

# Change to app directory for setup
cd /opt/workbook_importer

# Check what files are available
echo "Checking repository contents:"
ls -la

# Add a health check endpoint to the Flask app
echo "Adding health check to the Flask app"
cat > /opt/workbook_importer/health_check.py <<'EOF'
from flask import Blueprint

health_bp = Blueprint('health', __name__)

@health_bp.route('/health')
def health_check():
    return 'OK', 200
EOF

# Modify the app.py file to add the health check endpoint
if [ -f /opt/workbook_importer/app.py ]; then
    # Create a backup of the original app.py
    cp /opt/workbook_importer/app.py /opt/workbook_importer/app.py.bak
    
    # Ensure the app has the health check
    if ! grep -q "health_bp" /opt/workbook_importer/app.py; then
        echo "Modifying app.py to include health check"
        # Add the health check to app.py by inserting it near the top imports
        sed -i '1s/^/from health_check import health_bp\n/' /opt/workbook_importer/app.py
        
        # Add the blueprint registration after app = Flask(__name__)
        if grep -q "app = Flask" /opt/workbook_importer/app.py; then
            sed -i '/app = Flask/a app.register_blueprint(health_bp)' /opt/workbook_importer/app.py
        fi
    fi
else
    echo "WARNING: app.py not found - creating a placeholder"
    cat > /opt/workbook_importer/app.py <<'EOF'
from flask import Flask, render_template, request, redirect, url_for
from health_check import health_bp

app = Flask(__name__)
app.register_blueprint(health_bp)

@app.route('/')
def index():
    return '<h1>Workbook Importer</h1><p>Welcome to the Workbook Importer application.</p>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
EOF
fi

# Install Python dependencies
echo "Installing Python dependencies"
pip3 install -r requirements.txt

# Configure Nginx as a reverse proxy with a clean configuration
cat > /etc/nginx/conf.d/flask_app.conf <<'EOF'
server {
    listen 80 default_server;
    server_name localhost;

    access_log /var/log/nginx/flask_access.log;
    error_log /var/log/nginx/flask_error.log;

    # Root directory for static files
    root /usr/share/nginx/html;

    # For health checks and static content
    location = / {
        index index.html;
        try_files $uri /index.html;
    }

    # Forward requests to the Flask application with /app prefix
    location /app {
        proxy_pass http://127.0.0.1:5001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint for load balancer
    location = /health {
        proxy_pass http://127.0.0.1:5001/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Serve static files directly if they exist
    location /static {
        alias /opt/workbook_importer/static;
    }

    # Information pages
    location /info.html {
    }
    
    location /connectivity.html {
    }
}
EOF

# Verify Nginx configuration
echo "Verifying Nginx configuration"
nginx -t

# Apply Nginx settings
echo "Starting Nginx"
systemctl start nginx
systemctl enable nginx

# Create a systemd service for the Workbook Importer Flask app
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
Environment=FLASK_APP=app.py
Environment=FLASK_ENV=production

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

# Wait for services to fully start
sleep 5

# Check service status and log it
systemctl status nginx > /opt/workbook_importer/nginx_status.log
systemctl status flask_app.service > /opt/workbook_importer/flask_status.log

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
echo
echo "=== Health check test ==="
curl -v http://localhost/health
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

# Test connectivity from within the instance and log results
echo "Testing instance connectivity:" > /usr/share/nginx/html/connectivity.html
echo "<pre>" >> /usr/share/nginx/html/connectivity.html
echo "Local Nginx: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/)" >> /usr/share/nginx/html/connectivity.html
echo "Local Flask: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/)" >> /usr/share/nginx/html/connectivity.html
echo "Local Flask via Nginx: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/app)" >> /usr/share/nginx/html/connectivity.html
echo "Health check: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)" >> /usr/share/nginx/html/connectivity.html
echo "</pre>" >> /usr/share/nginx/html/connectivity.html

# Log completion of user data script
echo "User data script completed at $(date)"