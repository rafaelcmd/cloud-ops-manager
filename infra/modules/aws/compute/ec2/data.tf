data "aws_ami" "cloud_ops_manager_api_latest" {
  most_recent = true
  owners = ["self"]

  filter {
    name   = "name"
    values = ["cloud_ops_manager_api-*"]
  }

  filter {
    name   = "name"
    values = ["cloud_ops_manager_api-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}