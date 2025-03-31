resource "aws_ssm_parameter" "resource_provisioner_api_sqs_queue_url" {
  name  = "/RESOURCE_PROVISIONER_API/SQS_QUEUE_URL"
  type  = "String"
  value = "RESOURCE_PROVISIONER_API_SQS_QUEUE_URL"
}