terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2" # London
}

resource "aws_vpc" "web_vpc" {
  cidr_block           = var.network_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

resource "aws_subnet" "web_subnet" {
  # Use the count meta-parameter to create multiple copies
  count             = 2
  vpc_id            = aws_vpc.web_vpc.id
  # cidrsubnet function splits a cidr block into subnets
  cidr_block        = cidrsubnet(var.network_cidr, 2, count.index)
  # element retrieves a list element at a given index
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.app_name}-subnet-${count.index + 1}"
  }
}

resource "aws_instance" "web" {
  count                  = var.instance_count
  # lookup returns a map value for a given key
  ami                    = lookup(var.ami_ids, "eu-west-2")
  instance_type          = var.instance_type
  # Use the public subnet ids for instances to ensure they get public IPs
  subnet_id              = element(aws_subnet.public_subnet.*.id, count.index % length(aws_subnet.public_subnet.*.id))
  
  # Use instance user_data to install and configure the applications
  user_data              = file("user_data_compact.sh")
  
  # Attach the web server security group
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  # Make sure the instance can reach the internet
  associate_public_ip_address = true
  
  # Add an SSH key if you have one (optional)
  # key_name                   = "your-key-name"

  # Increase the timeout for user data script execution
  timeouts {
    create = "20m"
  }
  
  tags = { 
    Name = "${var.app_name}-server-${count.index + 1}" 
  }
  
  # Enforce IMDSv2 to prevent SSRF attacks
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
    encrypted   = true
    delete_on_termination = true
    
    tags = {
      Name = "${var.app_name}-volume-${count.index + 1}"
    }
  }

  # Make sure the VPC and subnets are ready before launching instances
  depends_on = [
    aws_subnet.public_subnet,
    aws_route_table_association.public_subnet_rta
  ]
}