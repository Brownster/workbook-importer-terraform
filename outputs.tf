output "private_ips" {
  description = "Private IP addresses of the Workbook Importer instances"
  value       = join(", ", aws_instance.web.*.private_ip)
}

output "public_ips" {
  description = "Public IP addresses of the Workbook Importer instances"
  value       = join(", ", aws_instance.web.*.public_ip)
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer for the Network Tools Suite"
  value       = aws_lb.web.dns_name
}

output "application_url" {
  description = "URL to access the Network Tools Suite"
  value       = "http://${aws_lb.web.dns_name}"
}

output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = join(", ", aws_instance.web.*.id)
}

output "app_name" {
  description = "Application name"
  value       = var.app_name
}