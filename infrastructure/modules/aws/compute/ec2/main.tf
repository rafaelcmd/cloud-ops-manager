resource "aws_instance" "resource-provisioner-api" {
  ami = "ami-08b5b3a93ed654d19"
  instance_type = "t2.micro"
  subnet_id = var.public_subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name = aws_key_pair.generated_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "resource-provisioner-api"
  }
}