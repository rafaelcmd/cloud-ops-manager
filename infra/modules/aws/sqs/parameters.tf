resource "aws_ssm_parameter" "provisioner_queue_url" {
  name  = "/CLOUD_OPS_MANAGER/PROVISIONER_QUEUE_URL"
  type  = "String"
  value = aws_sqs_queue.provisioner_queue.url
}