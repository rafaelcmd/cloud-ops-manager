resource "aws_instance" "resource-provisioner-api" {
  ami = "ami-08b5b3a93ed654d19"
  instance_type = "t2.micro"
  subnet_id = var.public_subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name = aws_key_pair.generated_key.key_name

  tags = {
    Name = "resource-provisioner-api"
  }
}

output "resource_provisioner_api_host" {
  value = aws_instance.resource-provisioner-api.public_ip
}

output "resource_provisioner_api_username" {
  value = "ec2-user"
}

output "resource_provisioner_api_private_key" {
  value = aws_key_pair.generated_key.key_name
}