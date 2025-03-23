#!/bin/bash

# This script includes additional diagnostics for troubleshooting connectivity issues
# Copy it to your EC2 instance and run it as root

echo "===== CHECKING NGINX CONFIG ====="
nginx -t
echo ""

echo "===== NGINX CONF DIRECTORY CONTENT ====="
ls -la /etc/nginx/conf.d/
cat /etc/nginx/conf.d/flask_app.conf
echo ""

echo "===== CHECKING DEFAULT NGINX CONF ====="
ls -la /etc/nginx/nginx.conf
grep -A 10 "server {" /etc/nginx/nginx.conf
echo ""

echo "===== ACTIVE LISTENERS ====="
netstat -tulpn | grep -E ':(80|5001)'
echo ""

echo "===== FIREWALL STATUS ====="
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --list-all
elif command -v iptables &> /dev/null; then
    iptables -L -n
else
    echo "No firewall command found"
fi
echo ""

echo "===== TESTING LOCAL ACCESS ====="
curl -v http://localhost/
echo ""
curl -v http://localhost/app
echo ""
curl -v http://localhost:5001/
echo ""

echo "===== TESTING HEALTH CHECK ====="
curl -I http://localhost/
echo ""

echo "===== CHECKING ROUTES ====="
ip route
echo ""

echo "===== CHECKING CONNECTIVITY ====="
ping -c 2 8.8.8.8
echo ""

echo "===== CHECKING NGINX ERROR LOG ====="
tail -n 20 /var/log/nginx/error.log
echo ""
tail -n 20 /var/log/nginx/flask_error.log
echo ""

echo "===== CHECKING SECURITY GROUPS ====="
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID: $INSTANCE_ID"
echo ""

echo "===== CHECKING LOAD BALANCER CONNECTIVITY ====="
ELB_DNS=$(grep load_balancer_dns /opt/workbook_importer/instance_info.txt | cut -d' ' -f2)
if [ -n "$ELB_DNS" ]; then
    echo "Testing connectivity to ELB: $ELB_DNS"
    curl -v $ELB_DNS
else
    echo "ELB DNS not found"
fi
echo ""