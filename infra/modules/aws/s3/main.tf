resource "aws_s3_bucket" "cloud_ops_manager_consumer_deploy_bucket" {
  bucket = "cloud-ops-manager-consumer-deploy-bucket"
  force_destroy = true

  tags = {
    Name = "cloud-ops-manager-consumer-deploy-bucket"
  }
}