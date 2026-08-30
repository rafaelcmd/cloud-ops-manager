locals {
  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = var.service_name
  }

  service_account_name      = "internal-developer-platform-provisioner"
  service_account_namespace = "default"
}
