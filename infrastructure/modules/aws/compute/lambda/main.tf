resource "aws_lambda_function" "auth_lambda" {
  filename         = "${path.module}/auth.zip"
  function_name    = "auth_lambda"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "auth.handler"
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("${path.module}/auth.zip")

  environment {
    variables = {
      USER_POOL_ID        = var.user_pool_id
      USER_POOL_CLIENT_ID = var.user_pool_client_id
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
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

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "api_gateway_invoke_auth" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn =
}