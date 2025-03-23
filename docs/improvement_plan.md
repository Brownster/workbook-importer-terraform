# Infrastructure Improvement Plan

This document outlines prioritized improvements to enhance the security, resilience, and operational efficiency of the Workbook Importer infrastructure.

## Priority 1: Critical Security Enhancements

### 1.1 AWS Provider Versioning
```hcl
provider "aws" {
  region  = "eu-west-2"
  version = "~> 3.0"
}
```

### 1.2 Management IP Validation
Update `variables.tf` with validation:
```hcl
variable "management_ip" {
  description = "IP address allowed to SSH to instances"
  validation {
    condition     = var.management_ip != "0.0.0.0"
    error_message = "Management IP must be set to your specific IP address, not 0.0.0.0."
  }
}
```

### 1.3 EC2 Instance Security
Add to `main.tf` EC2 resource:
```hcl
# Enforce IMDSv2
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"
  http_put_response_hop_limit = 1
}

# Enable encryption for EBS volumes
root_block_device {
  encrypted = true
}
```

## Priority 2: Resilience Improvements

### 2.1 Auto Scaling Group
Replace direct EC2 instances with an Auto Scaling Group:
```hcl
resource "aws_launch_configuration" "web_lc" {
  name_prefix   = "${var.app_name}-lc-"
  image_id      = lookup(var.ami_ids, "eu-west-2")
  instance_type = var.instance_type
  security_groups = [aws_security_group.web_sg.id]
  user_data     = file("user_data.sh")
  
  root_block_device {
    volume_size = 20
    encrypted   = true
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name                 = "${var.app_name}-asg"
  launch_configuration = aws_launch_configuration.web_lc.name
  min_size             = var.instance_count
  max_size             = var.instance_count * 2
  desired_capacity     = var.instance_count
  health_check_type    = "ELB"
  health_check_grace_period = 300
  load_balancers       = [aws_elb.web.name]
  vpc_zone_identifier  = aws_subnet.public_subnet.*.id
  
  tag {
    key                 = "Name"
    value               = "${var.app_name}-server"
    propagate_at_launch = true
  }
}
```

### 2.2 CloudWatch Alarms
```hcl
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.app_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}
```

## Priority 3: Operational Improvements

### 3.1 Centralized Logging
```hcl
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.app_name}"
  retention_in_days = 30
  
  tags = {
    Application = var.app_name
    Environment = "production"
  }
}
```

Update user_data.sh to install and configure CloudWatch agent.

### 3.2 IAM Role for EC2
```hcl
resource "aws_iam_role" "ec2_role" {
  name = "${var.app_name}-ec2-role"
  
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.app_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
```

## Priority 4: Remote State Management

### 4.1 S3 Backend
Create a dedicated S3 backend configuration:

1. First, create the S3 bucket and DynamoDB table manually or with a separate Terraform config.
2. Then configure backend in main.tf:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "workbook-importer/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Implementation Timeline

1. **Week 1**: Implement Priority 1 items (Critical Security)
2. **Week 2**: Implement Priority 2 items (Resilience)
3. **Week 3**: Implement Priority 3 items (Operations)
4. **Week 4**: Implement Priority 4 items (State Management)

## Testing Procedure

After each phase:
1. Run `terraform plan` to verify changes
2. Apply changes to a staging environment first if available
3. Test functionality via the load balancer
4. Verify security using AWS Config rules or Security Hub
5. Document any issues and fixes