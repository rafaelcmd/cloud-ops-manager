# A Secrets Manager secret, the customer-managed KMS key that encrypts it, and
# an alias for that key. Holds credentials the platform must not keep in
# Terraform, such as the scaffolder's GitHub App private key.
#
# The module creates the secret but no secret version, and takes no input for
# the value. The material is written out of band with
# `aws secretsmanager put-secret-value`, so it never passes through a plan, a
# state file or a CI log. Omitting the input makes that structural rather than a
# convention.
#
# The key is customer-managed rather than AWS-managed so it can be scoped: a
# reader needs kms:Decrypt on this key in addition to
# secretsmanager:GetSecretValue on the secret, and a kms:ViaService condition
# confines the key to Secrets Manager. It costs roughly $1/month and keeps
# billing through its deletion window after a destroy.

resource "aws_kms_key" "this" {
  description             = var.kms_key_description != null ? var.kms_key_description : "Encrypts ${var.name}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = var.tags
}

resource "aws_kms_alias" "this" {
  name          = var.alias_name
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_secretsmanager_secret" "this" {
  name        = var.name
  description = var.description
  kms_key_id  = aws_kms_key.this.arn

  # Zero lets a destroy/apply cycle reuse the name immediately. Anything higher
  # keeps the name reserved and fails the next apply with "already scheduled for
  # deletion". Use zero only in environments rebuilt from scratch.
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}
