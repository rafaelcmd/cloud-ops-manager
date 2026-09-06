# The platform's public edge: a REST API Gateway fronting the Go API, with a
# Cognito authorizer, WAF, throttling and a VPC Link into the private subnets.
# Nothing reaches the API except through this gateway.
#
# The API surface is not defined here. It is imported from the Go service's own
# OpenAPI specification, so the contract has one source of truth and the gateway
# cannot drift from the code that serves it.

locals {
  openapi_spec_path = "${path.module}/../../../../services/api/docs/swagger.yaml"

  # The API is versioned by path, for example /v1/resources. var.api_version
  # selects the current one, var.deprecated_versions lists those still served,
  # and var.enable_deprecation_headers adds the RFC 8594 headers.
  api_version_path_prefix = "/${var.api_version}"
}

# The OpenAPI document is a template: the VPC Link id, NLB address and Cognito
# pool ARN are Terraform values substituted into the AWS extensions at apply.
resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = "${var.api_description} (${var.api_version})"

  body = templatefile(local.openapi_spec_path, {
    nlb_uri               = "http://${var.nlb_dns_name}"
    vpc_link_id           = aws_api_gateway_vpc_link.this.id
    cognito_user_pool_arn = var.cognito_user_pool_arn
    api_version           = var.api_version
    aws_region            = var.aws_region
  })

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  # A spec that imports with warnings usually means an AWS extension was not
  # applied, which fails silently at runtime rather than at apply.
  fail_on_warnings = true

  minimum_compression_size = var.minimum_compression_size

  tags = merge(var.tags, {
    Name        = var.api_name
    Project     = var.project
    Environment = var.environment
    ApiVersion  = var.api_version
  })
}

# Lets the gateway reach the internal NLB in the private subnets. A REST API
# VPC Link targets the load balancer ARN directly; HTTP API VPC Links take
# subnets and security groups, so examples for those do not transfer.
resource "aws_api_gateway_vpc_link" "this" {
  name        = var.vpc_link_name
  description = "VPC Link for ${var.api_name}"
  target_arns = [var.nlb_arn]

  tags = merge(var.tags, {
    Name        = var.vpc_link_name
    Project     = var.project
    Environment = var.environment
    ApiVersion  = var.api_version
  })
}

# API Gateway serves the deployment a stage points at, not the REST API
# resource, so a spec change with no new deployment leaves the old API live.
# Hashing the rendered spec into a trigger forces the redeployment.
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(templatefile(local.openapi_spec_path, {
      nlb_uri               = "http://${var.nlb_dns_name}"
      vpc_link_id           = aws_api_gateway_vpc_link.this.id
      cognito_user_pool_arn = var.cognito_user_pool_arn
      api_version           = var.api_version
      aws_region            = var.aws_region
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_rest_api.this]
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name

  xray_tracing_enabled = var.xray_tracing_enabled

  # One JSON line per request. requestId is echoed back to callers in the
  # X-Request-Id header by the gateway responses below, so a user-reported
  # failure can be found in the logs from the id alone.
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId         = "$context.requestId"
      extendedRequestId = "$context.extendedRequestId"
      ip                = "$context.identity.sourceIp"
      caller            = "$context.identity.caller"
      user              = "$context.identity.user"
      requestTime       = "$context.requestTime"
      httpMethod        = "$context.httpMethod"
      resourcePath      = "$context.resourcePath"
      status            = "$context.status"
      protocol          = "$context.protocol"
      responseLength    = "$context.responseLength"
      integrationError  = "$context.integrationErrorMessage"
      errorMessage      = "$context.error.message"
      errorType         = "$context.error.responseType"
    })
  }

  cache_cluster_enabled = var.cache_cluster_enabled
  cache_cluster_size    = var.cache_cluster_enabled ? var.cache_cluster_size : null

  tags = merge(var.tags, {
    Name        = "${var.api_name}-${var.stage_name}"
    Project     = var.project
    Environment = var.environment
    ApiVersion  = var.api_version
  })

  depends_on = [aws_cloudwatch_log_group.api_gateway_logs]
}

# Applied to every method (*/*) rather than per route, so a new path in the
# OpenAPI spec inherits the throttling and logging settings automatically.
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit

    logging_level = var.logging_level
    # Logs full request and response bodies. Keep off outside debugging: it
    # writes caller-supplied payloads to CloudWatch.
    data_trace_enabled = var.data_trace_enabled
    metrics_enabled    = var.metrics_enabled

    caching_enabled = var.cache_cluster_enabled
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/apigateway/${var.api_name}"
    Project     = var.project
    Environment = var.environment
    ApiVersion  = var.api_version
  })
}

# API Gateway's CloudWatch role is a single account-wide, region-wide setting
# rather than a per-API one. Only one stack may own it, so a second caller of
# this module in the same account and region must set
# create_api_gateway_account = false or it will overwrite the first.
resource "aws_api_gateway_account" "this" {
  count               = var.create_api_gateway_account ? 1 : 0
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch[0].arn

  depends_on = [aws_iam_role_policy_attachment.api_gateway_cloudwatch]
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  count = var.create_api_gateway_account ? 1 : 0
  name  = "${var.api_name}-api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.api_name}-api-gateway-cloudwatch-role"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  count      = var.create_api_gateway_account ? 1 : 0
  role       = aws_iam_role.api_gateway_cloudwatch[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# REST APIs support direct WAFv2 association on the stage, so no CloudFront
# distribution is needed to put a Web ACL in front of the API.
resource "aws_wafv2_web_acl_association" "api_gateway" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_api_gateway_stage.this.arn
  web_acl_arn  = var.waf_web_acl_arn
}

# Errors raised by the gateway itself, before a request ever reaches the API:
# rejected tokens, failed request validation, throttling and WAF blocks. Without
# these, callers get AWS's default XML-ish bodies, which do not match the JSON
# error shape the API returns and carry no request id to quote in a bug report.
resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = "UNAUTHORIZED"
  status_code   = "401"

  response_templates = {
    "application/json" = jsonencode({
      code      = "UNAUTHORIZED"
      message   = "Missing or invalid authentication token"
      requestId = "$context.requestId"
    })
  }

  response_parameters = {
    "gatewayresponse.header.X-Request-Id"                = "'$context.requestId'"
    "gatewayresponse.header.X-API-Version"               = "'${var.api_version}'"
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_gateway_response" "access_denied" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = "ACCESS_DENIED"
  status_code   = "403"

  response_templates = {
    "application/json" = jsonencode({
      code      = "ACCESS_DENIED"
      message   = "Access denied"
      requestId = "$context.requestId"
    })
  }

  response_parameters = {
    "gatewayresponse.header.X-Request-Id"                = "'$context.requestId'"
    "gatewayresponse.header.X-API-Version"               = "'${var.api_version}'"
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_gateway_response" "bad_request" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = "BAD_REQUEST_BODY"
  status_code   = "400"

  response_templates = {
    "application/json" = jsonencode({
      code      = "VALIDATION_ERROR"
      message   = "Request body validation failed"
      requestId = "$context.requestId"
    })
  }

  response_parameters = {
    "gatewayresponse.header.X-Request-Id"                = "'$context.requestId'"
    "gatewayresponse.header.X-API-Version"               = "'${var.api_version}'"
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_gateway_response" "throttled" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = "THROTTLED"
  status_code   = "429"

  response_templates = {
    "application/json" = jsonencode({
      code      = "RATE_LIMITED"
      message   = "Too many requests. Please retry later."
      requestId = "$context.requestId"
    })
  }

  response_parameters = {
    "gatewayresponse.header.X-Request-Id"                = "'$context.requestId'"
    "gatewayresponse.header.X-API-Version"               = "'${var.api_version}'"
    "gatewayresponse.header.Retry-After"                 = "'60'"
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_gateway_response" "internal_error" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = "DEFAULT_5XX"
  status_code   = "500"

  response_templates = {
    "application/json" = jsonencode({
      code      = "INTERNAL_ERROR"
      message   = "An internal error occurred"
      requestId = "$context.requestId"
    })
  }

  response_parameters = {
    "gatewayresponse.header.X-Request-Id"                = "'$context.requestId'"
    "gatewayresponse.header.X-API-Version"               = "'${var.api_version}'"
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_gateway_response" "waf_blocked" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = "WAF_FILTERED"
  status_code   = "403"

  response_templates = {
    "application/json" = jsonencode({
      code      = "WAF_BLOCKED"
      message   = "Request blocked by security rules"
      requestId = "$context.requestId"
    })
  }

  response_parameters = {
    "gatewayresponse.header.X-Request-Id"                = "'$context.requestId'"
    "gatewayresponse.header.X-API-Version"               = "'${var.api_version}'"
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'"
  }
}
