locals {
  # Derived from the lengths of the principal lists so the decision is known at
  # plan time. Deriving it from the rendered policy document would make the
  # count depend on ARNs that may not exist yet, which fails with "Invalid count
  # argument".
  create_queue_policy = (
    length(var.producer_role_arns) > 0 ||
    length(var.producer_service_principals) > 0 ||
    length(var.consumer_role_arns) > 0
  )
}
