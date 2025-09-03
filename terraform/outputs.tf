output "public_ip" {
  value       = aws_instance.app.public_ip
  description = "Public IP of EC2"
}

output "public_dns" {
  value       = aws_instance.app.public_dns
  description = "Public DNS of EC2"
}
