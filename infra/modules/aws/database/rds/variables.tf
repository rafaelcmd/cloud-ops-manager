variable "rds_subnet_group" {
  description = "RDS Subnet Group"
  type        = string
}

variable "rds_security_group_ids" {
  description = "RDS Security Group IDs"
  type        = list(string)
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
}