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

resource "aws_api_gateway_integration" "cloud_ops_manager_api_root_get_ec2_integration" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method = aws_api_gateway_method.cloud_ops_manager_api_root_get.http_method

  integration_http_method = "GET"
  type                    = "HTTP"
  uri                     = "http://${var.cloud_ops_manager_api_host}:5000/resource-provisioner"
}

resource "aws_api_gateway_integration_response" "cloud_ops_manager_api_ec2_integration_response_get_200" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method = aws_api_gateway_method.cloud_ops_manager_api_root_get.http_method
  status_code = aws_api_gateway_method_response.cloud_ops_manager_api_root_get_200.status_code

  response_templates = {
    "application/json" = ""
  }

  depends_on = [
    aws_api_gateway_integration.cloud_ops_manager_api_root_get_ec2_integration
  ]
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

resource "aws_api_gateway_integration" "cloud_ops_manager_api_root_post_ec2_integration" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method = aws_api_gateway_method.cloud_ops_manager_api_root_post.http_method

  integration_http_method = "POST"
  type                    = "HTTP"
  uri                     = "http://${var.cloud_ops_manager_api_host}:5000/resource-provisioner"
}

resource "aws_api_gateway_integration_response" "cloud_ops_manager_api_ec2_integration_response_post_202" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method = aws_api_gateway_method.cloud_ops_manager_api_root_post.http_method
  status_code = aws_api_gateway_method_response.cloud_ops_manager_api_root_post_202.status_code

  response_templates = {
    "application/json" = ""
  }

  depends_on = [
    aws_api_gateway_integration.cloud_ops_manager_api_root_post_ec2_integration
  ]
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

resource "aws_api_gateway_deployment" "cloud_ops_manager_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.cloud_ops_manager_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.cloud_ops_manager_api_root_post,
    aws_api_gateway_integration.cloud_ops_manager_api_root_post_ec2_integration,
    aws_api_gateway_method_response.cloud_ops_manager_api_root_post_202,
    aws_api_gateway_integration_response.cloud_ops_manager_api_ec2_integration_response_post_202,
    aws_api_gateway_method.cloud_ops_manager_api_root_get,
    aws_api_gateway_integration.cloud_ops_manager_api_root_get_ec2_integration,
    aws_api_gateway_method_response.cloud_ops_manager_api_root_get_200,
    aws_api_gateway_integration_response.cloud_ops_manager_api_ec2_integration_response_get_200
  ]
}

resource "aws_api_gateway_stage" "cloud_ops_manager_api_dev_stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  deployment_id = aws_api_gateway_deployment.cloud_ops_manager_api_deployment.id
}

resource "aws_api_gateway_usage_plan" "cloud_ops_manager_api_usage_plan" {
  name        = "CloudOps Manager API Usage Plan"
  description = "Usage plan for Cloud Ops Manager API"

  api_stages {
    api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
    stage  = aws_api_gateway_stage.cloud_ops_manager_api_dev_stage.stage_name
  }

  throttle_settings {
    rate_limit  = 100
    burst_limit = 50
  }

  depends_on = [
    aws_api_gateway_stage.cloud_ops_manager_api_dev_stage,
    aws_api_gateway_deployment.cloud_ops_manager_api_deployment
  ]
}

resource "aws_api_gateway_api_key" "cloud_ops_manager_api_key" {
  name        = "CloudOps Manager API Key"
  description = "API Key for Cloud Ops Manager API"
  enabled     = true

  tags = {
    Name = "CloudOps Manager API Key"
  }
}

resource "aws_api_gateway_usage_plan_key" "cloud_ops_manager_api_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.cloud_ops_manager_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.cloud_ops_manager_api_usage_plan.id
}

