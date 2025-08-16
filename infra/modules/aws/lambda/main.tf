# Create archive from source directory
data "archive_file" "lambda_code" {
  type        = "zip"
  output_path = "${path.module}/lambda-${var.function_name}.zip"
  source_dir  = var.source_dir
}

# Lambda function
resource "aws_lambda_function" "this" {
  function_name                  = var.function_name
  role                           = aws_iam_role.lambda_role.arn
  handler                        = var.handler
  runtime                        = var.runtime
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  reserved_concurrent_executions = var.reserved_concurrent_executions

  filename         = data.archive_file.lambda_code.output_path
  source_code_hash = data.archive_file.lambda_code.output_base64sha256

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda_logs,
  ]

  tags = var.tags

  lifecycle {
    ignore_changes = [reserved_concurrent_executions]
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

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

  tags = var.tags
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach additional policies if provided
resource "aws_iam_role_policy_attachment" "additional" {
  count      = length(var.additional_policies)
  role       = aws_iam_role.lambda_role.name
  policy_arn = var.additional_policies[count.index]
}

# Additional inline IAM policy for Lambda-specific permissions
resource "aws_iam_role_policy" "lambda_additional_policy" {
  count = var.additional_inline_policy != null ? 1 : 0

  name = "${var.function_name}-additional-policy"
  role = aws_iam_role.lambda_role.id

  policy = var.additional_inline_policy
}

# Lambda permission for CloudWatch Logs to invoke the function
resource "aws_lambda_permission" "cloudwatch_logs" {
  count = var.allow_cloudwatch_logs_invocation ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "logs.amazonaws.com"

  # Optional source ARN for more specific permissions
  source_arn = var.cloudwatch_logs_source_arn != null ? var.cloudwatch_logs_source_arn : null
}

# CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
