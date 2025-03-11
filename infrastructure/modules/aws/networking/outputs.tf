output "vpc_id" {
  description = "VPC ID"
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value = aws_subnet.public_subnet.id
}