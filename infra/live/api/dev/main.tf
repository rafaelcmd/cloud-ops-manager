# This stack owns the cluster every platform workload runs on, the queue between
# the API and the provisioner, and the load balancer the public API Gateway
# reaches. Sibling stacks consume all three through the SSM parameters published
# at the bottom of this file.

module "eks" {
  source = "../../../modules/aws/eks"

  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)

  aws_region  = var.aws_region
  environment = var.environment
  project     = var.project

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  endpoint_public_access  = var.cluster_endpoint_public_access
  endpoint_private_access = true
  public_access_cidrs     = var.cluster_public_access_cidrs

  # The API and Redis run in `default`. kube-system is included so CoreDNS and
  # the load balancer controller can schedule, since the cluster has no nodes.
  fargate_namespaces = var.fargate_namespaces

  log_retention_days = var.cluster_log_retention_days

  # Reconciles TargetGroupBinding, which keeps Fargate pod IPs registered in the
  # target group created by module.api_nlb below.
  install_aws_load_balancer_controller       = true
  aws_load_balancer_controller_chart_version = var.aws_load_balancer_controller_chart_version

  # Cluster-level visibility only: pod inventory and the orchestrator explorer.
  # Application telemetry goes to the OTel Collector instead.
  install_datadog_cluster_agent = true
  datadog_chart_version         = var.datadog_chart_version
  datadog_api_key               = data.aws_ssm_parameter.datadog_api_key.value

  # Pods labeled `agent.datadoghq.com/sidecar: fargate` (see k8s/api, k8s/redis)
  # get a datadog-agent sidecar injected, which is the only way live pod status
  # is reported on Fargate. The ServiceAccounts listed back those pods and
  # receive the kubelet-read RBAC the sidecar needs.
  datadog_sidecar_namespaces = ["default"]
  datadog_sidecar_service_accounts = [
    { namespace = "default", name = "internal-developer-platform-api" },
    { namespace = "default", name = "internal-developer-platform-provisioner" },
    { namespace = "default", name = "default" }, # redis runs on the default SA
  ]

  # Namespace, IRSA ServiceAccount and Datadog secret for the Collector, which
  # is the single egress point for the platform's telemetry. The workload itself
  # is applied from k8s/otel-collector. amp_workspace_arn is left unset: the
  # datadog exporter needs no AWS credentials.
  install_otel_collector = true

  # Managed Fluent Bit ships pod stdout to one CloudWatch log group. Kept as a
  # vendor-neutral archive that also captures early crash output a process never
  # gets onto OTLP. See observability.tf.
  enable_fargate_logging     = true
  fargate_log_retention_days = var.cluster_log_retention_days

  # Operator workstations, the deploy role, and the CI role of every stack whose
  # Terraform touches Kubernetes objects. Without an entry the kubernetes
  # provider fails with a bare "Unauthorized".
  cluster_admin_principal_arns = var.cluster_admin_principal_arns

  tags = local.tags
}

# The seam between the API and the rest of the platform. The API returns 202 as
# soon as a request is on this queue; the provisioner consumes it and drives
# everything downstream.
module "sqs" {
  source = "../../../modules/aws/sqs"

  queue_name                = var.queue_name
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size
  message_retention_seconds = var.message_retention_seconds
  receive_wait_time_seconds = var.receive_wait_time_seconds

  # Set explicitly rather than left on the module's 30s default. The provisioner
  # is the platform's control plane: once it starts Step Functions executions, a
  # message must stay invisible long enough for that call to finish, or SQS
  # delivers the same request to a second consumer and the work runs twice.
  visibility_timeout_seconds = var.queue_visibility_timeout_seconds

  # A message here is a provision request that was accepted with a 202 and then
  # never carried out, which is invisible to the caller without an alarm.
  alarm_actions = [module.observability_alerts.topic_arn]

  # No queue policy, deliberately. Both counterparties are IAM roles in this
  # account, authorized by their own identity policies: the API's grant is in
  # irsa.tf here, the provisioner's in live/provisioner/dev/irsa.tf. An SQS
  # policy is an additive allow, so it could not restrict them anyway.
  #
  # It also could not name the consumer. SQS validates principals when the
  # policy is set, and the provisioner's role is created by a stack that applies
  # after this one, so a fresh build would fail with "InvalidAttributeValue:
  # Invalid value for the parameter Policy". The module's queue policy exists
  # for principals that carry no identity policy at all, such as the
  # states.amazonaws.com principal on the scaffolder's task queues.

  tags = local.tags
}

# The internal load balancer the API Gateway VPC Link targets. Terraform owns it
# so its ARN is a stable value the gateway stack can read from SSM; a
# TargetGroupBinding in k8s/api registers the pod IPs into the target group.
module "api_nlb" {
  source = "../../../modules/aws/nlb"

  nlb_name           = var.api_nlb_name
  internal           = true
  load_balancer_type = "network"
  subnets            = split(",", data.aws_ssm_parameter.private_subnet_ids.value)

  target_group_name     = var.api_target_group_name
  target_group_port     = var.api_target_group_port
  target_group_protocol = "TCP"
  vpc_id                = data.aws_ssm_parameter.vpc_id.value
  target_type           = "ip"

  health_check_enabled  = true
  health_check_protocol = "HTTP"
  health_check_port     = tostring(var.api_target_group_port)
  health_check_path     = var.api_target_group_health_check_path
  health_check_interval = 30
  health_check_timeout  = 6
  healthy_threshold     = 3
  unhealthy_threshold   = 3

  listener_port     = var.api_nlb_listener_port
  listener_protocol = "TCP"

  project     = var.project
  environment = var.environment
  tags        = local.tags
}

resource "aws_ssm_parameter" "api_nlb_arn" {
  name  = var.api_nlb_arn_ssm_parameter_name
  type  = "String"
  value = module.api_nlb.nlb_arn

  tags = local.tags
}

resource "aws_ssm_parameter" "api_nlb_dns" {
  name  = var.api_nlb_dns_ssm_parameter_name
  type  = "String"
  value = module.api_nlb.nlb_dns_name

  tags = local.tags
}

resource "aws_ssm_parameter" "api_target_group_arn" {
  name  = var.api_target_group_arn_ssm_parameter_name
  type  = "String"
  value = module.api_nlb.target_group_arn

  tags = local.tags
}

# Redis runs as an in-cluster Deployment (k8s/redis) reachable over cluster DNS,
# not as an AWS-managed service. Its address is published here anyway so the API
# resolves every piece of its configuration the same way, from SSM at startup.
resource "aws_ssm_parameter" "redis_endpoint" {
  name  = var.redis_ssm_parameter_name
  type  = "String"
  value = var.redis_endpoint

  tags = local.tags
}

# The queue's URL, which is the form the AWS SDKs take. Both the API and the
# provisioner resolve it at startup.
#
# Published by this stack rather than by modules/aws/sqs: which parameter path
# the callers agreed on is a property of the platform, not of a reusable queue
# module.
resource "aws_ssm_parameter" "provisioner_queue_url" {
  name  = var.ssm_parameter_name
  type  = var.ssm_parameter_type
  value = module.sqs.queue_url

  tags = local.tags
}

# The same queue's ARN, for stacks writing IAM policies against it, currently
# the provisioner's IRSA role in live/provisioner/dev. Both forms are published
# because deriving one from the other in HCL would mean hard-coding an account
# id.
resource "aws_ssm_parameter" "provisioner_queue_arn" {
  name  = "/idp/shared/provisioner/queue_arn"
  type  = "String"
  value = module.sqs.queue_arn

  tags = local.tags
}
