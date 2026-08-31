# =============================================================================
# ENCRYPTED SECRET
#
# A Secrets Manager secret, the customer-managed KMS key that encrypts it, and
# an alias for that key.
#
# The module creates the secret but NEVER a secret version, and takes no input
# for the value. That is the point of it: the material is put in out of band
# with `aws secretsmanager put-secret-value`, so it never passes through a plan,
# a state file or a CI log. A module that accepted the value would make the
# careful handling optional; leaving the input out makes it structural.
#
# A customer-managed key rather than the AWS-managed one, because it can be
# scoped: a reader needs kms:Decrypt on this key as well as
# secretsmanager:GetSecretValue on the secret, and a kms:ViaService condition
# confines the key to Secrets Manager. It costs about $1/month, and it keeps
# billing through its deletion window after a destroy.
# =============================================================================

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

  # Zero lets a destroy/apply cycle reuse the name immediately; anything higher
  # keeps the name reserved and fails the next apply with "already scheduled for
  # deletion". Environments that are rebuilt from scratch want zero, everything
  # else wants the recovery window.
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}
