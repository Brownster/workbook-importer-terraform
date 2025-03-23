resource "aws_security_group" "elb_sg" {
  name        = "${var.app_name}-elb-sg"
  description = "Allow incoming HTTP traffic from the internet"
  vpc_id      = aws_vpc.web_vpc.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from anywhere"
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "${var.app_name}-elb-sg"
  }
}

resource "aws_security_group" "web_sg" {
  name        = "${var.app_name}-web-sg"
  description = "Allow HTTP traffic from ELB and SSH for management"
  vpc_id      = aws_vpc.web_vpc.id
  
  # HTTP access from anywhere (for testing)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from anywhere for testing"
  }
  
  # HTTP access for the Flask app directly (for testing)
  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Flask app traffic (port 5001) from anywhere for testing"
  }
  
  # HTTP access from the ELB (keep this too)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
    description     = "Allow HTTP traffic from the load balancer"
  }
  
  # HTTP access for Flask from ELB (keep this too)
  ingress {
    from_port       = 5001
    to_port         = 5001
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
    description     = "Allow Flask app traffic (port 5001) from the load balancer"
  }
  
#  # SSH access for management
#  ingress {
#    from_port   = 22
#    to_port     = 22
#    protocol    = "tcp"
#    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP: ["your-ip/32"]
#    description = "Allow SSH access for management"
#  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "${var.app_name}-web-sg"
  }
}
