#!/bin/bash

# Enable detailed logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution at $(date)"

# Create a diagnostics log file
DIAG_LOG="/var/log/instance-setup.log"
touch $DIAG_LOG
chmod 644 $DIAG_LOG

log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $DIAG_LOG
}

log_command() {
  log_message "Running command: $1"
  eval "$1" >> $DIAG_LOG 2>&1
  log_message "Command exit status: $?"
}

log_message "Instance setup starting"

# Update system packages - Amazon Linux 2 uses yum
log_message "Updating system packages"
log_command "yum update -y"
log_command "yum install -y python3 python3-pip git"

# Install dependencies
log_message "Installing dependencies"
log_command "amazon-linux-extras install -y epel nginx1"
log_command "yum install -y wkhtmltopdf telnet nc wget"

# Create directory structure
log_message "Creating directory structure"
log_command "mkdir -p /usr/share/nginx/html /opt/workbook_importer /opt/workbook_exporter /opt/firewall_generator /opt/logs"

# Create a simple health check page immediately
log_message "Creating health check page"
echo "<html><body><h1>Server is up</h1><p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p></body></html>" > /usr/share/nginx/html/index.html

# Configure and start Nginx immediately for health checks
log_message "Configuring basic Nginx"
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

cat > /etc/nginx/conf.d/default.conf <<'EOF'
server {
    listen 80 default_server;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
    
    # Add info.html endpoint
    location = /info.html {
        default_type text/html;
    }
}
EOF

# Create info.html page
log_message "Creating info.html page"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

cat > /usr/share/nginx/html/info.html <<EOF
<html>
<head><title>Instance Info</title></head>
<body>
<h1>Instance Information</h1>
<pre>
Instance ID: ${INSTANCE_ID}
Private IP: ${PRIVATE_IP}
Public IP: ${PUBLIC_IP}
</pre>
</body>
</html>
EOF

# Start Nginx immediately for health checks
log_message "Starting Nginx service"
log_command "nginx -t"
log_command "systemctl start nginx"
log_command "systemctl enable nginx"

# Check if Nginx is running
log_message "Checking if Nginx is running"
log_command "systemctl status nginx"
log_command "curl -s http://localhost/"

# Clone repositories with retries
log_message "Cloning application repositories"
for repo in "workbook_importer" "workbook_exporter" "portmapper"; do
  dest_dir=""
  case $repo in
    "workbook_importer") dest_dir="/opt/workbook_importer" ;;
    "workbook_exporter") dest_dir="/opt/workbook_exporter" ;;
    "portmapper") dest_dir="/opt/firewall_generator" ;;
  esac
  
  log_message "Cloning $repo to $dest_dir"
  attempts=0
  while [ $attempts -lt 3 ]; do
    if git clone "https://github.com/Brownster/$repo.git" "$dest_dir"; then
      log_message "Successfully cloned $repo"
      break
    else
      attempts=$((attempts+1))
      log_message "Failed to clone $repo (attempt $attempts/3)"
      sleep 5
    fi
  done
  
  if [ $attempts -eq 3 ]; then
    log_message "Failed to clone $repo after 3 attempts"
  fi
done

# Try to download the full configuration script from GitHub
log_message "Attempting to download configuration script from GitHub"
cd /opt

# Create a function to report completion to CloudWatch
create_completion_marker() {
  log_message "Creating completion marker"
  touch /usr/share/nginx/html/setup-complete.html
  cat > /usr/share/nginx/html/setup-complete.html <<EOF
<html>
<head><title>Setup Complete</title></head>
<body>
<h1>Instance Setup Complete</h1>
<p>Instance ID: ${INSTANCE_ID}</p>
<p>Setup completed at: $(date)</p>
</body>
</html>
EOF
  log_message "Setup complete marker created"

  # Set proper permissions for all directories
  log_command "chown -R ec2-user:ec2-user /opt/workbook_importer /opt/workbook_exporter /opt/firewall_generator"
}

# Try to download and run the configuration script
attempts=0
while [ $attempts -lt 3 ]; do
  if wget https://raw.githubusercontent.com/Brownster/workbook-importer-terraform/main/scripts/configure_services.sh; then
    log_message "Download successful. Running configuration script..."
    chmod +x configure_services.sh
    log_command "./configure_services.sh"
    create_completion_marker
    break
  else
    attempts=$((attempts+1))
    log_message "Failed to download script from GitHub (attempt $attempts/3)"
    sleep 10
  fi
done

# If download failed after all attempts, use the basic configuration
if [ $attempts -eq 3 ]; then
  log_message "Failed to download script after 3 attempts. Using basic configuration."
  
  # Create a simple flask app configuration
  log_message "Setting up basic flask app configuration"
  cat > /etc/nginx/conf.d/apps.conf <<'EOF'
server {
    listen 80 default_server;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    # Main landing page
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Health check endpoint
    location = /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
    
    # Add info.html endpoint
    location = /info.html {
        default_type text/html;
    }
    
    # Add setup-complete.html endpoint
    location = /setup-complete.html {
        default_type text/html;
    }
}
EOF

  # Reload Nginx to apply the new configuration
  log_command "nginx -t"
  log_command "systemctl reload nginx"
  
  create_completion_marker
fi

# Final check to make sure everything is running
log_message "Performing final health check"
log_command "systemctl status nginx"
log_command "curl -s http://localhost/"
log_command "curl -s http://localhost/health"
log_command "curl -s http://localhost/info.html"

# Log completion of user data script
log_message "User data script completed at $(date)"