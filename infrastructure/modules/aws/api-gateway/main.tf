resource "aws_api_gateway_rest_api" "resource_provisioner_api" {
  name        = "ResourceProvisionerAPI"
  description = "API Gateway for Resource Provisioner API"
}

resource "aws_api_gateway_resource" "resource_provisioner_api_root" {
  rest_api_id = aws_api_gateway_rest_api.resource_provisioner_api.id
  parent_id   = aws_api_gateway_rest_api.resource_provisioner_api.root_resource_id
  path_part   = "resource-provisioner"
}

resource "aws_api_gateway_method" "resource_provisioner_api_root_post" {
  rest_api_id   = aws_api_gateway_rest_api.resource_provisioner_api.id
  resource_id   = aws_api_gateway_resource.resource_provisioner_api_root.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "resource_provisioner_api_root_post_ec2" {
  rest_api_id = aws_api_gateway_rest_api.resource_provisioner_api.id
  resource_id = aws_api_gateway_resource.resource_provisioner_api_root.id
  http_method = aws_api_gateway_method.resource_provisioner_api_root_post.http_method

  integration_http_method = "POST"
  type                    = "HTTP"
  uri                     = "http://${var.resource_provisioner_api_host}:5000/resource-provisioner"
}

resource "aws_api_gateway_method_response" "resource_provisioner_api_root_post_200" {
  rest_api_id = aws_api_gateway_rest_api.resource_provisioner_api.id
  resource_id = aws_api_gateway_resource.resource_provisioner_api_root.id
  http_method = aws_api_gateway_method.resource_provisioner_api_root_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "resource_provisioner_api_root_post_200" {
  rest_api_id = aws_api_gateway_rest_api.resource_provisioner_api.id
  resource_id = aws_api_gateway_resource.resource_provisioner_api_root.id
  http_method = aws_api_gateway_method.resource_provisioner_api_root_post.http_method
  status_code = aws_api_gateway_method_response.resource_provisioner_api_root_post_200.status_code

  response_templates = {
    "application/json" = ""
  }

  depends_on = [
    aws_api_gateway_integration.resource_provisioner_api_root_post_ec2
  ]
}

resource "aws_api_gateway_deployment" "resource_provisioner_api" {
  rest_api_id = aws_api_gateway_rest_api.resource_provisioner_api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.resource_provisioner_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.resource_provisioner_api_root_post,
    aws_api_gateway_integration.resource_provisioner_api_root_post_ec2,
    aws_api_gateway_method_response.resource_provisioner_api_root_post_200,
    aws_api_gateway_integration_response.resource_provisioner_api_root_post_200
  ]
}

resource "aws_api_gateway_stage" "resource_provisioner_api" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.resource_provisioner_api.id
  deployment_id = aws_api_gateway_deployment.resource_provisioner_api.id
}