resource "aws_sqs_queue" "resource_provisioner_queue" {
  name                      = "resource_provisioner_queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 20
}