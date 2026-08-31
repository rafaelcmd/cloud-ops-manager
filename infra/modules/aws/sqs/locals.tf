locals {
  # Whether a policy is created has to be knowable at plan time, so it is derived
  # from the lengths of the principal lists rather than from anything the policy
  # document produces. Deciding it from the rendered document would make the
  # count depend on an ARN that does not exist yet, which fails the plan with
  # "Invalid count argument" — the same trap modules/aws/irsa hit.
  create_queue_policy = (
    length(var.producer_role_arns) > 0 ||
    length(var.producer_service_principals) > 0 ||
    length(var.consumer_role_arns) > 0
  )
}
