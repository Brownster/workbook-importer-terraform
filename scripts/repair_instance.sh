#!/bin/bash

echo "Network Tools Suite Repair Script"
echo "================================="

# Function to log messages
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check and fix Nginx
check_nginx() {
  log_message "Checking Nginx..."
  
  if ! systemctl is-active --quiet nginx; then
    log_message "Nginx is not running. Attempting to fix..."
    
    # Remove any problematic config
    log_message "Removing current Nginx configurations..."
    rm -f /etc/nginx/conf.d/*.conf
    
    # Create simple configuration
    log_message "Creating basic Nginx configuration..."
    cat > /etc/nginx/conf.d/simple.conf <<'EOF'
server {
    listen 80 default_server;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location = /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

    # Fix permissions
    log_message "Fixing permissions..."
    mkdir -p /var/log/nginx
    chmod 755 /var/log/nginx
    chown nginx:nginx /var/log/nginx
    
    # Test and restart Nginx
    log_message "Testing and restarting Nginx..."
    nginx -t && systemctl restart nginx
    
    # Check if successful
    if systemctl is-active --quiet nginx; then
      log_message "Nginx repair successful!"
    else
      log_message "Nginx repair failed. Check nginx -t output for errors."
    fi
  else
    log_message "Nginx is running correctly."
  fi
}

# Check and fix application services
check_services() {
  for service in workbook_importer workbook_exporter firewall_generator; do
    log_message "Checking $service..."
    
    if ! systemctl is-active --quiet $service.service; then
      log_message "$service is not running. Restarting..."
      systemctl restart $service.service
      
      if systemctl is-active --quiet $service.service; then
        log_message "$service restarted successfully."
      else
        log_message "$service failed to start. Checking logs..."
        journalctl -u $service.service --no-pager -n 20
      fi
    else
      log_message "$service is running correctly."
    fi
  done
}

# Check and create static pages
check_static_pages() {
  log_message "Checking static pages..."
  
  # Ensure directory structure exists
  mkdir -p /usr/share/nginx/html/static
  mkdir -p /usr/share/nginx/html/importer
  mkdir -p /usr/share/nginx/html/exporter
  mkdir -p /usr/share/nginx/html/firewall
  
  # Fix permissions
  chmod 755 /usr/share/nginx/html
  chmod 755 /usr/share/nginx/html/static
  chmod 755 /usr/share/nginx/html/importer
  chmod 755 /usr/share/nginx/html/exporter
  chmod 755 /usr/share/nginx/html/firewall
  
  # Create basic pages if they don't exist
  for app in "importer" "exporter" "firewall"; do
    if [ ! -f "/usr/share/nginx/html/$app/index.html" ]; then
      log_message "Creating $app static page..."
      
      case "$app" in
        "importer") title="Workbook Importer" ;;
        "exporter") title="Workbook Exporter" ;;
        "firewall") title="Firewall Request Generator" ;;
      esac
      
      cat > "/usr/share/nginx/html/$app/index.html" <<EOF
<html>
<head><title>$title</title></head>
<body>
<h1>$title</h1>
<p>This is a basic version of the $title application.</p>
<p>The full application is still being configured.</p>
<p><a href="/">Return to Home</a></p>
</body>
</html>
EOF
    fi
  done
  
  # Create health page if it doesn't exist
  if [ ! -f "/usr/share/nginx/html/health.html" ]; then
    log_message "Creating health status page..."
    cat > /usr/share/nginx/html/health.html <<EOF
<html>
<head><title>Health Status</title></head>
<body>
<h1>Health Status</h1>
<p>Server: <span style="color:green">✓ Online</span></p>
<p>Services being configured. Full health status will be available soon.</p>
<p><a href="/">Return to Home</a></p>
</body>
</html>
EOF
  fi
}

# Main repair sequence
main() {
  log_message "Starting repair sequence..."
  
  check_static_pages
  check_nginx
  check_services
  
  log_message "Repair sequence completed."
}

# Run the main function
main