#!/bin/bash

echo "Configuring services and applications..."

# =====================================
# Nginx Configuration
# =====================================
# Remove default configuration files that might conflict
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

# Create landing page
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

# =====================================
# Application Setup
# =====================================

# Create global health check blueprint
cat > /opt/health_check.py <<'EOF'
from flask import Blueprint

health_bp = Blueprint('health', __name__)

@health_bp.route('/health')
def health_check():
    return 'OK', 200
EOF

# Configure each application
for app in "workbook_importer" "workbook_exporter" "firewall_generator"; do
  # Copy health check to each app directory
  cp /opt/health_check.py /opt/$app/
  
  # Install requirements
  cd /opt/$app
  pip3 install -r requirements.txt
done

# Install gunicorn for Workbook Exporter
pip3 install gunicorn

# =====================================
# Service Configuration
# =====================================

# Systemd service for Workbook Importer
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

# Systemd service for Workbook Exporter
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

# Systemd service for Firewall Request Generator
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

# =====================================
# Nginx Application Configuration
# =====================================

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

# Create diagnostic script
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
chmod +x /opt/check_services.sh

# =====================================
# Start Services
# =====================================

# Verify and start Nginx
nginx -t
systemctl start nginx
systemctl enable nginx

# Start and enable application services
systemctl daemon-reload
systemctl enable workbook_importer.service workbook_exporter.service firewall_generator.service
systemctl start workbook_importer.service workbook_exporter.service firewall_generator.service

# Run checks and create info pages
/opt/check_services.sh > /opt/service_check_results.log 2>&1

# Create instance info file
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

cat > /usr/share/nginx/html/info.html <<EOL
<h1>Instance Information:</h1>
<pre>
Instance ID: $INSTANCE_ID
Region: $REGION
Private IP: $PRIVATE_IP
Public IP: $PUBLIC_IP
</pre>
EOL

echo "Configuration complete!"