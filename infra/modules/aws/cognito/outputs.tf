output "cloud_ops_manager_api_user_pool_id" {
  value = aws_cognito_user_pool.cloud_ops_manager_api_user_pool.id
}

output "cloud_ops_manager_api_user_pool_client_id" {
  value = aws_cognito_user_pool_client.cloud_ops_manager_api_user_pool_client.id
}