resource "aws_ssm_parameter" "cloud_ops_manager_consumer_deploy_bucket_name" {
  name  = "/CLOUD_OPS_MANAGER_CONSUMER/DEPLOY_BUCKET_NAME"
  type  = "String"
  value = aws_s3_bucket.cloud_ops_manager_consumer_deploy_bucket.bucket
}