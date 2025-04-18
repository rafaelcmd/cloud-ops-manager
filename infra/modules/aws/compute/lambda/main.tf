resource "aws_lambda_function" "cloud_ops_manager_api_auth_lambda" {
  filename         = "${path.module}/auth.zip"
  function_name    = "auth_lambda"
  role             = aws_iam_role.cloud_ops_manager_api_auth_lambda_exec.arn
  handler          = "auth.handler"
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/auth.zip")

  environment {
    variables = {
      USER_POOL_ID        = var.cloud_ops_manager_api_user_pool_id
      USER_POOL_CLIENT_ID = var.cloud_ops_manager_api_user_pool_client_id
    }
  }
}

resource "aws_iam_role" "cloud_ops_manager_api_auth_lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_api_auth_lambda_exec_policy" {
  role       = aws_iam_role.cloud_ops_manager_api_auth_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "cloud_ops_manager_api_gateway_invoke_auth" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloud_ops_manager_api_auth_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${var.cloud_ops_manager_api_deployment_execution_arn}*/*/*"
}

resource "aws_iam_policy" "cloud_ops_manager_api_auth_lambda_cognito_policy" {
  name        = "lambda_cognito_policy"
  description = "Policy for Lambda to access Cognito"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:InitiateAuth",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_api_auth_lambda_cognito_policy_attachment" {
  role       = aws_iam_role.cloud_ops_manager_api_auth_lambda_exec.name
  policy_arn = aws_iam_policy.cloud_ops_manager_api_auth_lambda_cognito_policy.arn
}

resource "aws_iam_policy" "cloud_ops_manager_api_auth_lambda_ssm_get_parameter" {
  name        = "ssm_get_parameter_policy"
  description = "Policy for Lambda to access SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloud_ops_manager_api_auth_lambda_ssm_get_parameter_attachment" {
  role       = aws_iam_role.cloud_ops_manager_api_auth_lambda_exec.name
  policy_arn = aws_iam_policy.cloud_ops_manager_api_auth_lambda_ssm_get_parameter.arn
}