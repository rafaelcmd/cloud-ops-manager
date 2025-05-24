output "cloud_ops_manager_api_pipeline_arn" {
  value = aws_imagebuilder_image_pipeline.cloud_ops_manager_api_pipeline.arn
}

output "cloud_ops_manager_api_image_id" {
  value = aws_imagebuilder_image.cloud_ops_manager_api_image.id
}