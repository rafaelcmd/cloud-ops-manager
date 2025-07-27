resource "aws_sqs_queue" "provisioner_queue" {
  name                      = "provisioner_queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 20
}