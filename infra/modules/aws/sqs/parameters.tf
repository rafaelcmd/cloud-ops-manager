resource "aws_ssm_parameter" "provisioner_queue_url" {
  name  = var.ssm_parameter_name
  type  = var.ssm_parameter_type
  value = aws_sqs_queue.provisioner_queue.url

  tags = var.tags
}