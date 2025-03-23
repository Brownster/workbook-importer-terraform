#!/bin/bash

# Enable detailed logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution at $(date)"

# Update system packages - Amazon Linux 2 uses yum
yum update -y
yum install -y python3 python3-pip git

# Install wkhtmltopdf for PDF generation (needed for Firewall Request Generator)
echo "Installing wkhtmltopdf"
amazon-linux-extras install -y epel
yum install -y wkhtmltopdf

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

# Create an attractive landing page
cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Network Tools Suite</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f7f9fc;
        }
        .container {
            width: 80%;
            margin: 0 auto;
            padding: 2rem;
        }
        header {
            background-color: #2c3e50;
            color: white;
            padding: 2rem 0;
            text-align: center;
            margin-bottom: 2rem;
            border-bottom: 5px solid #3498db;
        }
        h1 {
            margin: 0;
            font-size: 2.5rem;
        }
        .description {
            max-width: 700px;
            margin: 1rem auto;
            font-size: 1.1rem;
        }
        .app-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 2rem;
            margin-top: 2rem;
        }
        .app-card {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            overflow: hidden;
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        .app-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 12px 16px rgba(0,0,0,0.1);
        }
        .app-header {
            background-color: #3498db;
            color: white;
            padding: 1.5rem;
            text-align: center;
        }
        .app-body {
            padding: 1.5rem;
        }
        .app-title {
            margin: 0;
            font-size: 1.5rem;
        }
        .app-description {
            color: #666;
            margin-bottom: 1.5rem;
        }
        .btn {
            display: inline-block;
            background-color: #3498db;
            color: white;
            text-decoration: none;
            padding: 0.8rem 1.5rem;
            border-radius: 4px;
            font-weight: 600;
            text-align: center;
            transition: background-color 0.3s ease;
            width: 100%;
        }
        .btn:hover {
            background-color: #2980b9;
        }
        footer {
            margin-top: 3rem;
            text-align: center;
            color: #7f8c8d;
            font-size: 0.9rem;
        }
        .health-status {
            background-color: #e8f4fd;
            border-radius: 4px;
            padding: 0.5rem;
            text-align: center;
            margin-top: 2rem;
        }
    </style>
</head>
<body>
    <header>
        <h1>Network Tools Suite</h1>
        <p class="description">Comprehensive tools for managing your network configurations</p>
    </header>
    
    <div class="container">
        <div class="app-grid">
            <div class="app-card">
                <div class="app-header">
                    <h2 class="app-title">Workbook Importer</h2>
                </div>
                <div class="app-body">
                    <p class="app-description">Import and process network workbooks efficiently with this tool.</p>
                    <a href="/importer" class="btn">Launch Application</a>
                </div>
            </div>
            
            <div class="app-card">
                <div class="app-header">
                    <h2 class="app-title">Workbook Exporter</h2>
                </div>
                <div class="app-body">
                    <p class="app-description">Export network configurations to standardized workbooks.</p>
                    <a href="/exporter" class="btn">Launch Application</a>
                </div>
            </div>
            
            <div class="app-card">
                <div class="app-header">
                    <h2 class="app-title">Firewall Request Generator</h2>
                </div>
                <div class="app-body">
                    <p class="app-description">Generate properly formatted firewall change requests.</p>
                    <a href="/firewall" class="btn">Launch Application</a>
                </div>
            </div>
        </div>
        
        <div class="health-status">
            All services operational | <a href="/info.html">Server Info</a> | <a href="/health">Health Status</a>
        </div>
    </div>
    
    <footer>
        &copy; 2025 Network Tools Suite | Deployed with AWS & Terraform
    </footer>
</body>
</html>
EOF

# Create global health check blueprint
cat > /opt/health_check.py <<'EOF'
from flask import Blueprint

health_bp = Blueprint('health', __name__)

@health_bp.route('/health')
def health_check():
    return 'OK', 200
EOF

# ---- WORKBOOK IMPORTER ----
echo "Setting up Workbook Importer"
mkdir -p /opt/workbook_importer
git clone https://github.com/Brownster/workbook_importer.git /opt/workbook_importer
cd /opt/workbook_importer

# Add health check to Workbook Importer
cp /opt/health_check.py /opt/workbook_importer/health_check.py
if [ -f /opt/workbook_importer/app.py ]; then
    cp /opt/workbook_importer/app.py /opt/workbook_importer/app.py.bak
    if ! grep -q "health_bp" /opt/workbook_importer/app.py; then
        sed -i '1s/^/from health_check import health_bp\n/' /opt/workbook_importer/app.py
        if grep -q "app = Flask" /opt/workbook_importer/app.py; then
            sed -i '/app = Flask/a app.register_blueprint(health_bp)' /opt/workbook_importer/app.py
        fi
    fi
else
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

# Install dependencies for Workbook Importer
pip3 install -r requirements.txt

# Create systemd service for Workbook Importer
cat > /etc/systemd/system/workbook_importer.service <<'EOF'
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

# ---- WORKBOOK EXPORTER ----
echo "Setting up Workbook Exporter"
mkdir -p /opt/workbook_exporter
git clone https://github.com/Brownster/workbook_exporter.git /opt/workbook_exporter
cd /opt/workbook_exporter

# Add health check to Workbook Exporter
cp /opt/health_check.py /opt/workbook_exporter/health_check.py
if [ -f /opt/workbook_exporter/workbook_exporter-fe5.py ]; then
    cp /opt/workbook_exporter/workbook_exporter-fe5.py /opt/workbook_exporter/workbook_exporter-fe5.py.bak
    if ! grep -q "health_bp" /opt/workbook_exporter/workbook_exporter-fe5.py; then
        sed -i '1s/^/from health_check import health_bp\n/' /opt/workbook_exporter/workbook_exporter-fe5.py
        if grep -q "app = Flask" /opt/workbook_exporter/workbook_exporter-fe5.py; then
            sed -i '/app = Flask/a app.register_blueprint(health_bp)' /opt/workbook_exporter/workbook_exporter-fe5.py
        fi
    fi
fi

# Install dependencies for Workbook Exporter
pip3 install -r requirements.txt
pip3 install gunicorn

# Create systemd service for Workbook Exporter
cat > /etc/systemd/system/workbook_exporter.service <<'EOF'
[Unit]
Description=Workbook Exporter Flask App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/opt/workbook_exporter
ExecStart=/usr/local/bin/gunicorn -w 2 -b 127.0.0.1:5002 workbook_exporter-fe5:app
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=FLASK_APP=workbook_exporter-fe5.py
Environment=FLASK_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# ---- FIREWALL REQUEST GENERATOR ----
echo "Setting up Firewall Request Generator"
mkdir -p /opt/firewall_generator
git clone https://github.com/Brownster/portmapper.git /opt/firewall_generator
cd /opt/firewall_generator

# Add health check to Firewall Request Generator
cp /opt/health_check.py /opt/firewall_generator/health_check.py
if [ -f /opt/firewall_generator/app.py ]; then
    cp /opt/firewall_generator/app.py /opt/firewall_generator/app.py.bak
    if ! grep -q "health_bp" /opt/firewall_generator/app.py; then
        sed -i '1s/^/from health_check import health_bp\n/' /opt/firewall_generator/app.py
        if grep -q "app = Flask" /opt/firewall_generator/app.py; then
            sed -i '/app = Flask/a app.register_blueprint(health_bp)' /opt/firewall_generator/app.py
        fi
    fi
else
    cat > /opt/firewall_generator/app.py <<'EOF'
from flask import Flask, render_template, request, redirect, url_for
from health_check import health_bp

app = Flask(__name__)
app.register_blueprint(health_bp)

@app.route('/')
def index():
    return '<h1>Firewall Request Generator</h1><p>Welcome to the Firewall Request Generator application.</p>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5003)
EOF
fi

# Install dependencies for Firewall Request Generator
pip3 install -r requirements.txt

# Create systemd service for Firewall Request Generator
cat > /etc/systemd/system/firewall_generator.service <<'EOF'
[Unit]
Description=Firewall Request Generator Flask App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/opt/firewall_generator
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

# ---- NGINX CONFIGURATION ----
# Configure Nginx as a reverse proxy for all applications
cat > /etc/nginx/conf.d/apps.conf <<'EOF'
server {
    listen 80 default_server;
    server_name localhost;

    access_log /var/log/nginx/apps_access.log;
    error_log /var/log/nginx/apps_error.log;

    # Root directory for static files
    root /usr/share/nginx/html;

    # Main landing page
    location = / {
        index index.html;
    }

    # Health check endpoint for load balancer
    location = /health {
        proxy_pass http://127.0.0.1:5001/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Workbook Importer
    location /importer {
        proxy_pass http://127.0.0.1:5001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Workbook Exporter
    location /exporter {
        proxy_pass http://127.0.0.1:5002/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Firewall Request Generator
    location /firewall {
        proxy_pass http://127.0.0.1:5003/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files for all applications
    location /static/ {
        # Try each application's static folder
        try_files $uri @importer_static @exporter_static @firewall_static;
    }

    location @importer_static {
        alias /opt/workbook_importer/static/;
    }

    location @exporter_static {
        alias /opt/workbook_exporter/static/;
    }

    location @firewall_static {
        alias /opt/firewall_generator/static/;
    }

    # Information pages
    location /info.html { }
    location /connectivity.html { }
}
EOF

# Set proper permissions for all applications
chown -R ec2-user:ec2-user /opt/workbook_importer
chown -R ec2-user:ec2-user /opt/workbook_exporter
chown -R ec2-user:ec2-user /opt/firewall_generator

# Verify Nginx configuration
echo "Verifying Nginx configuration"
nginx -t

# Apply Nginx settings
echo "Starting Nginx"
systemctl start nginx
systemctl enable nginx

# Enable and start all services
echo "Starting all application services"
systemctl daemon-reload
systemctl enable workbook_importer.service
systemctl enable workbook_exporter.service
systemctl enable firewall_generator.service
systemctl start workbook_importer.service
systemctl start workbook_exporter.service
systemctl start firewall_generator.service

# Wait for services to fully start
sleep 10

# Check service status and log it
echo "Checking service status"
mkdir -p /opt/logs
systemctl status nginx > /opt/logs/nginx_status.log
systemctl status workbook_importer.service > /opt/logs/importer_status.log
systemctl status workbook_exporter.service > /opt/logs/exporter_status.log
systemctl status firewall_generator.service > /opt/logs/firewall_status.log

# Create a script to check service status
cat > /opt/check_services.sh <<'EOF'
#!/bin/bash
echo "=== System Status ==="
uptime
echo
echo "=== Nginx Status ==="
systemctl status nginx
echo
echo "=== Workbook Importer Status ==="
systemctl status workbook_importer.service
echo
echo "=== Workbook Exporter Status ==="
systemctl status workbook_exporter.service
echo
echo "=== Firewall Generator Status ==="
systemctl status firewall_generator.service
echo
echo "=== Nginx Configuration Test ==="
nginx -t
echo
echo "=== Network Ports Listening ==="
netstat -tulpn | grep -E ':(80|443|5001|5002|5003)'
echo
echo "=== Main Landing Page Test ==="
curl -s http://localhost/ | grep -o "<title>.*</title>"
echo
echo "=== Applications Access Test ==="
echo "Workbook Importer: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/importer)"
echo "Workbook Exporter: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/exporter)"
echo "Firewall Generator: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/firewall)"
echo
echo "=== Health Check Test ==="
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
echo "Nginx: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/)" >> /usr/share/nginx/html/connectivity.html
echo "Workbook Importer: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/importer)" >> /usr/share/nginx/html/connectivity.html
echo "Workbook Exporter: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/exporter)" >> /usr/share/nginx/html/connectivity.html
echo "Firewall Generator: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/firewall)" >> /usr/share/nginx/html/connectivity.html
echo "Health check: $(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)" >> /usr/share/nginx/html/connectivity.html
echo "</pre>" >> /usr/share/nginx/html/connectivity.html

# Log completion of user data script
echo "User data script completed at $(date)"