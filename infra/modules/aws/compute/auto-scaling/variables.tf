variable "cloud_ops_manager_api_security_group_id" {
  type        = string
  description = "Security Group ID"
}

variable "cloud_ops_manager_api_public_subnet_ids" {
  type        = list(string)
  description = "Public subnet ids list"
}

variable "cloud_ops_manager_api_tg_arn" {
  type        = string
  description = "LB target groups"
}