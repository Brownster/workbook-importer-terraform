# Architecture Overview

This document provides a detailed overview of the AWS infrastructure architecture deployed by this Terraform configuration.

## Components

### Networking
- **VPC**: A Virtual Private Cloud with CIDR block 192.168.100.0/24 that isolates the infrastructure
- **Subnets**: 
  - 2 private subnets for application instances (192.168.100.0/26, 192.168.100.64/26)
  - 2 public subnets for load balancer (192.168.100.128/26, 192.168.100.192/26)
- **Internet Gateway**: Provides internet access for resources in the VPC
- **Route Tables**: Define routing rules for traffic within and outside the VPC

### Compute
- **EC2 Instances**: Amazon Linux 2 instances running Python, Flask, and Nginx
- **User Data Script**: Automated bootstrap script that configures instances on startup

### Security
- **Security Groups**:
  - Load Balancer Security Group: Controls traffic to the load balancer
  - Web Server Security Group: Controls traffic to the EC2 instances

### Load Balancing
- **Elastic Load Balancer (ELB)**: Classic load balancer that distributes traffic to instances
- **Health Checks**: Monitors instance health using HTTP checks

## Traffic Flow

1. User request reaches the Elastic Load Balancer
2. ELB routes the request to a healthy EC2 instance
3. Nginx on the EC2 instance serves static content or forwards to Flask application
4. Flask application processes the request and returns a response
5. Response follows the reverse path back to the user

## Scaling and Resilience

The architecture is designed for high availability:
- Multiple instances across availability zones
- Health checks remove unhealthy instances from service
- Auto-recovery through Nginx and systemd service restart mechanisms