output "topic_arn" {
  description = "ARN of the topic — what a CloudWatch alarm takes as alarm_actions"
  value       = aws_sns_topic.this.arn
}

output "topic_name" {
  description = "Name of the topic"
  value       = aws_sns_topic.this.name
}

output "subscription_arns" {
  description = "ARNs of the created subscriptions, keyed by the caller's label. An unconfirmed email subscription reports as \"pending confirmation\" rather than an ARN."
  value       = { for k, s in aws_sns_topic_subscription.this : k => s.arn }
}
