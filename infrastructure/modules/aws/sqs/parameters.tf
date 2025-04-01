resource "aws_ssm_parameter" "resource_provisioner_api_sqs_queue_url" {
  name  = "/CLOUD_OPS_MANAGER/SQS_QUEUE_URL"
  type  = "String"
  value = aws_sqs_queue.resource_provisioner_queue.url
}