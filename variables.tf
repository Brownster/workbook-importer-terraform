# Network CIDR for VPC
variable "network_cidr" {
  description = "CIDR block for the VPC"
  default     = "192.168.100.0/24"
}

# Availability zones 
variable "availability_zones" {
  description = "AWS availability zones to deploy into"
  default     = ["eu-west-2a", "eu-west-2b"]
}

# Number of web instances to create
variable "instance_count" {
  description = "Number of EC2 instances to create"
  default     = 2
}

# AMI IDs for the instances - use the latest Amazon Linux 2 AMIs
variable "ami_ids" {
  description = "AMI IDs for different regions"
  default = {
    # Amazon Linux 2 AMIs - updated March 2023
    "eu-west-2" = "ami-04706e771f950937f"  # Amazon Linux 2 AMI in eu-west-2 (London)
    "us-west-2" = "ami-0c2d06d50ce30b442"  # Amazon Linux 2 AMI in us-west-2
    "us-east-1" = "ami-0cff7528ff583bf9a"  # Amazon Linux 2 AMI in us-east-1
  }
}

# Instance type
variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

# Application name
variable "app_name" {
  description = "Name of the application"
  default     = "workbook-importer"
}

# Management IP address for SSH access
variable "management_ip" {
  description = "IP address allowed to SSH to instances (use your own IP)"
  default     = "0.0.0.0"  # Change this to your IP address before deploying
}

# Domain name for HTTPS setup
variable "domain_name" {
  description = "Domain name for the application (required for HTTPS)"
  default     = ""  # e.g., "example.com" or "app.example.com"
}

# Enable HTTPS
variable "enable_https" {
  description = "Whether to enable HTTPS using ACM"
  type        = bool
  default     = false
}