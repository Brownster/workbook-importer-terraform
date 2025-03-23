resource "aws_elb" "web" {
  name            = "${var.app_name}-elb"
  subnets         = aws_subnet.public_subnet.*.id
  security_groups = [aws_security_group.elb_sg.id]
  instances       = aws_instance.web.*.id

  # Listen for HTTP requests and distribute them to the instances
  listener { 
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  # Health check configuration for the Flask application
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    target              = "HTTP:80/"  # Checking Nginx proxy
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
}