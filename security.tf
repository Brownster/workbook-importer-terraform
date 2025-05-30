resource "aws_security_group" "elb_sg" {
  name        = "${var.app_name}-alb-sg"
  description = "Allow incoming HTTP/HTTPS traffic from the internet"
  vpc_id      = aws_vpc.web_vpc.id
  
  # Allow HTTP from anywhere to the load balancer
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from anywhere"
  }
  
  # Allow HTTPS (443) when enabled
  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS traffic from anywhere"
    }
  }
  
  # Allow all outbound traffic for the load balancer
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic from the load balancer"
  }
  
  tags = {
    Name = "${var.app_name}-alb-sg"
  }
}

# Create the web security group first without the ELB references
resource "aws_security_group" "web_sg" {
  name        = "${var.app_name}-web-sg"
  description = "Restricted access security group for web servers"
  vpc_id      = aws_vpc.web_vpc.id
  
  # SSH access from your management IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.management_ip}/32"]  
    description = "Allow SSH access from management IP"
  }
  
  # SSH access from AWS EC2 Instance Connect
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
    description = "Allow SSH access from AWS EC2 Instance Connect"
  }
  
  # Restrict outbound access to necessary services
  
  # Allow HTTPS to GitHub (for git clone and pulls)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # GitHub IP ranges - these can change, so we'll use a wider range for reliability
    cidr_blocks = ["140.82.112.0/20", "192.30.252.0/22", "185.199.108.0/22"]
    description = "Allow HTTPS to GitHub"
  }
  
  # Allow HTTP for package repositories and updates
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP for package repositories"
  }
  
  # Allow HTTPS for package repositories and Python pip
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS for package repositories and PyPI"
  }
  
  # Allow DNS for domain name resolution
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow DNS queries"
  }
  
  # Allow NTP for time synchronization
  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow NTP for time synchronization"
  }
  
  tags = {
    Name = "${var.app_name}-web-sg"
  }
}

# Add HTTP ingress rule for web servers from the load balancer
resource "aws_security_group_rule" "web_http_from_alb" {
  security_group_id        = aws_security_group.web_sg.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.elb_sg.id
  description              = "Allow HTTP traffic from the Application Load Balancer"
}

# Flask is only accessed internally by Nginx, no need to open it to the ELB
# Port 5001 is only used internally on each instance