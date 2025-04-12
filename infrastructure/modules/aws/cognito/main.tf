resource "aws_cognito_user_pool" "cloud_ops_manager_api_user_pool" {
  name = "cloud-ops-manager-api-user-pool"

  password_policy {
    minimum_length    = 8
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
    require_lowercase = true
  }
}

resource "aws_cognito_user_pool_client" "cloud_ops_manager_api_user_pool_client" {
  name         = "cloud-ops-manager-api-user-pool-client"
  user_pool_id = aws_cognito_user_pool.cloud_ops_manager_api_user_pool.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}