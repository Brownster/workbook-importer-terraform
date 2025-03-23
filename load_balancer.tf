resource "aws_elb" "web" {
  name            = "${var.app_name}-elb"
  subnets         = aws_subnet.public_subnet.*.id
  security_groups = [aws_security_group.elb_sg.id]
  instances       = aws_instance.web.*.id

  # HTTP listener - always exists
  listener { 
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  # HTTPS listener - only when enabled and certificate exists
  dynamic "listener" {
    for_each = var.enable_https && var.domain_name != "" ? [1] : []
    content {
      instance_port      = 80
      instance_protocol  = "http"
      lb_port            = 443
      lb_protocol        = "https"
      ssl_certificate_id = aws_acm_certificate_validation.cert_validation[0].certificate_arn
    }
  }

  # Health check configuration - use TCP check which is more reliable
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    target              = "TCP:80"  # Simply check if the port is open
    interval            = 15
  }
  
  # Cross-zone load balancing distributes traffic evenly across all instances
  cross_zone_load_balancing = true
  
  # Connection draining ensures in-flight requests complete when instances are deregistered
  connection_draining = true
  connection_draining_timeout = 60
  
  tags = {
    Name = "${var.app_name}-elb"
  }
  
  # Give time for instances to initialize before adding them to the load balancer
  provisioner "local-exec" {
    command = "sleep 60"  # Wait for 60 seconds
  }
}