resource "aws_api_gateway_rest_api" "cloud_ops_manager_api" {
  name        = "Cloud_Ops_Manager_API"
  description = "API Gateway for Cloud Ops Manager API"
}

resource "aws_api_gateway_resource" "cloud_ops_manager_api_root" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  parent_id   = aws_api_gateway_rest_api.cloud_ops_manager_api.root_resource_id
  path_part   = "resource-provisioner"
}

resource "aws_api_gateway_method" "cloud_ops_manager_api_root_post" {
  rest_api_id   = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id   = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cloud_ops_manager_api_root_post_ec2" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method = aws_api_gateway_method.cloud_ops_manager_api_root_post.http_method

  integration_http_method = "POST"
  type                    = "HTTP"
  uri                     = "http://${var.cloud_ops_manager_api_host}:5000/resource-provisioner"
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

resource "aws_api_gateway_integration_response" "cloud_ops_manager_api_root_post_202" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  resource_id = aws_api_gateway_resource.cloud_ops_manager_api_root.id
  http_method = aws_api_gateway_method.cloud_ops_manager_api_root_post.http_method
  status_code = aws_api_gateway_method_response.cloud_ops_manager_api_root_post_202.status_code

  response_templates = {
    "application/json" = ""
  }

  depends_on = [
    aws_api_gateway_integration.cloud_ops_manager_api_root_post_ec2
  ]
}

resource "aws_api_gateway_deployment" "cloud_ops_manager_api" {
  rest_api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.cloud_ops_manager_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.cloud_ops_manager_api_root_post,
    aws_api_gateway_integration.cloud_ops_manager_api_root_post_ec2,
    aws_api_gateway_method_response.cloud_ops_manager_api_root_post_202,
    aws_api_gateway_integration_response.cloud_ops_manager_api_root_post_202
  ]
}

resource "aws_api_gateway_stage" "cloud_ops_manager_api" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.cloud_ops_manager_api.id
  deployment_id = aws_api_gateway_deployment.cloud_ops_manager_api.id
}

resource "aws_api_gateway_usage_plan" "cloud_ops_manager_api_usage_plan" {
  name        = "Cloud_Ops_Manager_API_Usage_Plan"
  description = "Usage plan for Cloud Ops Manager API"

  api_stages {
    api_id = aws_api_gateway_rest_api.cloud_ops_manager_api.id
    stage  = aws_api_gateway_stage.cloud_ops_manager_api.stage_name
  }

  throttle_settings {
    burst_limit = 50
    rate_limit  = 10
  }
}