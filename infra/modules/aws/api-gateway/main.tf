resource "aws_api_gateway_rest_api" "cloud_ops_manager_api" {
  name        = "CloudOps Manager API"
  description = "API Gateway for Cloud Ops Manager API"
}

resource "aws_api_gateway_resource" "cloud_ops_manager_api_root" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  parent_id   = aws_api_gateway_rest_api.cloud_ops_manager_api.root_resource_id
  path_part   = "resource-provisioner"
}

resource "aws_api_gateway_method" "cloud_ops_manager_api_root_get" {
  rest_api_id      = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id      = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method_response" "cloud_ops_manager_api_root_get_200" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method = aws_api_gateway_method.cloud_ops_manager_api_root_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method" "cloud_ops_manager_api_root_post" {
  rest_api_id      = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id      = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method_response" "cloud_ops_manager_api_root_post_202" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method = aws_api_gateway_method.cloud_ops_manager_api_root_post.http_method
  status_code = "202"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_resource" "cloud_ops_manager_api_auth" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  parent_id   = aws_api_gateway_rest_api.cloud_ops_manager_api.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "cloud_ops_manager_api_auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id   = aws_api_gateway_resource.cloud_ops_manager_api_auth.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cloud_ops_manager_api_auth_post_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id = aws_api_gateway_resource.cloud_ops_manager_api_auth.id
  http_method = aws_api_gateway_method.cloud_ops_manager_api_auth_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.auth_lambda_invoke_arn
}

resource "aws_api_gateway_api_key" "cloud_ops_manager_api_key" {
  name        = "CloudOps Manager API Key"
  description = "API Key for Cloud Ops Manager API"
  enabled     = true

  tags = {
    Name = "CloudOps Manager API Key"
  }
}

