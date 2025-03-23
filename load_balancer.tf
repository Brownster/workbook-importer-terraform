# Application Load Balancer
resource "aws_lb" "web" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]
  subnets            = aws_subnet.public_subnet.*.id
  
  enable_deletion_protection = false
  
  tags = {
    Name = "${var.app_name}-alb"
  }
}

# Target group for the backend instances
resource "aws_lb_target_group" "web" {
  name     = "${var.app_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.web_vpc.id
  
  health_check {
    enabled             = true
    interval            = 15
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }
  
  tags = {
    Name = "${var.app_name}-tg"
  }
}

# Register instances with the target group
resource "aws_lb_target_group_attachment" "web" {
  count            = length(aws_instance.web)
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# HTTP Listener for ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# HTTPS Listener for ALB (only when HTTPS is enabled and a domain is provided)
resource "aws_lb_listener" "https" {
  count             = var.enable_https && var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation[0].certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}