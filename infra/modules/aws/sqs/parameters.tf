resource "aws_ssm_parameter" "provisioner_consumer_sqs_queue_url" {
  name  = "/CLOUD_OPS_MANAGER/SQS_QUEUE_URL"
  type  = "String"
  value = aws_sqs_queue.resource_provisioner_sqs_queue.url
}