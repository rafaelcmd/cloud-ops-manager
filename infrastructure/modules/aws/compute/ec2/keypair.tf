resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_secretsmanager_secret" "resource-provisioner-api-private-key" {
  name = "resource-provisioner-api-private-key"
  description = "Private key for resource-provisioner-api"
}

resource "aws_secretsmanager_secret_version" "resource-provisioner-api-private-key" {
  secret_id = aws_secretsmanager_secret.resource-provisioner-api-private-key.id
  secret_string = tls_private_key.ssh_key.private_key_pem
}

resource "aws_key_pair" "generated_key" {
  key_name   = "resource-provisioner-api-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}