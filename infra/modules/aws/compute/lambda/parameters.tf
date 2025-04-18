resource "aws_ssm_parameter" "cloud_ops_manager_cognito_client_id" {
  name  = "/CLOUD_OPS_MANAGER_COGNITO/CLIENT_ID"
  type  = "String"
  value = var.cloud_ops_manager_api_user_pool_client_id
}