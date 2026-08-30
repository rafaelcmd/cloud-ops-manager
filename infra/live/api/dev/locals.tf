locals {
  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = var.service_name
  }
}
