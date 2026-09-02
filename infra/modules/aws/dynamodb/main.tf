# =============================================================================
# DYNAMODB TABLE
#
# A single table with an optional TTL attribute and optional global secondary
# indexes. Attributes are declared once, in var.attributes, and DynamoDB only
# wants the ones a key or an index actually uses — listing a plain data field
# there is rejected at apply.
# =============================================================================

resource "aws_dynamodb_table" "this" {
  name         = var.name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key

  # Read and write capacity are set only for PROVISIONED billing; on
  # PAY_PER_REQUEST DynamoDB rejects them.
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  dynamic "attribute" {
    for_each = var.attributes

    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Null disables TTL. When set, the application must write the attribute as
  # epoch seconds — the only shape DynamoDB evaluates.
  dynamic "ttl" {
    for_each = var.ttl_attribute_name != null ? [1] : []

    content {
      attribute_name = var.ttl_attribute_name
      enabled        = true
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes

    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = global_secondary_index.value.range_key
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.non_key_attributes
      read_capacity      = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
      write_capacity     = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  # Server-side encryption is always on in DynamoDB; this block only chooses the
  # key. Without it the table uses the AWS-owned key, which is free and cannot be
  # scoped — pass a CMK ARN where access to the key itself needs to be a control.
  dynamic "server_side_encryption" {
    for_each = var.kms_key_arn != null ? [1] : []

    content {
      enabled     = true
      kms_key_arn = var.kms_key_arn
    }
  }

  deletion_protection_enabled = var.deletion_protection_enabled

  tags = var.tags
}
