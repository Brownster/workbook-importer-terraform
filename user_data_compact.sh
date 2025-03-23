#!/bin/bash

# Enable detailed logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution at $(date)"

# Update system packages - Amazon Linux 2 uses yum
yum update -y
yum install -y python3 python3-pip git

# Install dependencies
amazon-linux-extras install -y epel nginx1
yum install -y wkhtmltopdf telnet nc wget

# Create directory structure
mkdir -p /usr/share/nginx/html /opt/workbook_importer /opt/workbook_exporter /opt/firewall_generator /opt/logs

# Clone repositories
git clone https://github.com/Brownster/workbook_importer.git /opt/workbook_importer
git clone https://github.com/Brownster/workbook_exporter.git /opt/workbook_exporter
git clone https://github.com/Brownster/portmapper.git /opt/firewall_generator

# Try to download the full configuration script from GitHub
cd /opt
echo "Attempting to download configuration script from GitHub..."
if wget https://raw.githubusercontent.com/Brownster/workbook-importer-terraform/main/scripts/configure_services.sh; then
  echo "Download successful. Running configuration script..."
  chmod +x configure_services.sh
  ./configure_services.sh
else
  echo "Failed to download script from GitHub. Creating basic configuration..."
  
  # Create basic Nginx configuration
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
    
    include /etc/nginx/conf.d/*.conf;
}
EOF

  # Create basic server configuration
  cat > /etc/nginx/conf.d/default.conf <<'EOF'
server {
    listen 80 default_server;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

  # Create basic index page
  cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Network Tools Suite</title>
</head>
<body>
    <h1>Network Tools Suite</h1>
    <p>Basic configuration mode active.</p>
    <p>For full functionality, ensure GitHub access is available.</p>
</body>
</html>
EOF

  # Create info page
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
  PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
  PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
  
  cat > /usr/share/nginx/html/info.html <<EOF
<h1>Instance Information:</h1>
<pre>
Instance ID: $INSTANCE_ID
Region: $REGION
Private IP: $PRIVATE_IP
Public IP: $PUBLIC_IP
</pre>
EOF

  # Start Nginx
  systemctl start nginx
  systemctl enable nginx
fi

# Set proper permissions
chown -R ec2-user:ec2-user /opt/workbook_importer /opt/workbook_exporter /opt/firewall_generator

# Log completion of user data script
echo "User data script completed at $(date)"