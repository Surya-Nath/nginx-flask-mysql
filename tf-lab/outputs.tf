output "public_dns" {
  value = aws_instance.lab.public_dns
}

output "public_ip" {
  value = aws_instance.lab.public_ip
}

output "instance_id" {
  value = aws_instance.lab.id
}
