resource "aws_ssm_parameter" "cloud_ops_manager_api_ec2_host" {
  name  = "/CLOUD_OPS_MANAGER_API/EC2_PUBLIC_IP"
  type  = "String"
  value = aws_instance.cloud_ops_manager_api_ec2.public_ip
}

resource "aws_ssm_parameter" "cloud_ops_manager_api_ec2_username" {
  name  = "/CLOUD_OPS_MANAGER_API/EC2_USERNAME"
  type  = "String"
  value = "ec2-user"
}

resource "aws_ssm_parameter" "cloud_ops_manager_api_ec2_instance_id" {
  name  = "/CLOUD_OPS_MANAGER_API/EC2_INSTANCE_ID"
  type  = "String"
  value = aws_instance.cloud_ops_manager_api_ec2.id
}

resource "aws_ssm_parameter" "cloud_ops_manager_consumer_ec2_instance_id" {
  name  = "/CLOUD_OPS_MANAGER_CONSUMER/EC2_INSTANCE_ID"
  type  = "String"
  value = aws_instance.cloud_ops_manager_consumer_ec2.id
}