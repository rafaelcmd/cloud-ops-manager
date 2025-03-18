resource "aws_ssm_parameter" "resource_provisioner_api_host" {
  name  = "/RESOURCE_PROVISIONER_API/EC2_PUBLIC_IP"
  type  = "String"
  value = ""
}

resource "aws_ssm_parameter" "resource_provisioner_api_username" {
  name  = "/RESOURCE_PROVISIONER_API/EC2_USERNAME"
  type  = "String"
  value = ""
}