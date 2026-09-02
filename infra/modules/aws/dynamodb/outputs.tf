output "table_name" {
  description = "Name of the table, which is what workloads take in their environment"
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the table, for the IAM policies written against it"
  value       = aws_dynamodb_table.this.arn
}

output "table_id" {
  description = "ID of the table"
  value       = aws_dynamodb_table.this.id
}

# The index ARNs are a separate grant from the table's: a policy allowing Query
# on the table alone cannot query an index.
output "index_arns" {
  description = "ARNs of the table's global secondary indexes, keyed by index name"
  value       = { for gsi in var.global_secondary_indexes : gsi.name => "${aws_dynamodb_table.this.arn}/index/${gsi.name}" }
}
