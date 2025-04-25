resource "aws_db_instance" "provisioner_rds_instance" {
  count                   = 0 # Set to 0 to disable RDS instance creation
  identifier              = "provisioner-rds-instance"
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "17.4"
  instance_class          = "db.t3.micro"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = var.rds_subnet_group
  vpc_security_group_ids  = var.rds_security_group_ids
  skip_final_snapshot     = true
  publicly_accessible     = false
  storage_encrypted       = true
  multi_az                = true
  backup_retention_period = 7
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name = "provisioner-rds-instance"
  }
}