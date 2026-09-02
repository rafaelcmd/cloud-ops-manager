module "eks" {
  source = "../../../modules/aws/eks"

  # Infrastructure dependencies — sourced from SSM (published by shared/vpc)
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)

  # Project / region
  aws_region  = var.aws_region
  environment = var.environment
  project     = var.project

  # Cluster
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Endpoint access
  endpoint_public_access  = var.cluster_endpoint_public_access
  endpoint_private_access = true
  public_access_cidrs     = var.cluster_public_access_cidrs

  # Pods schedule onto Fargate. The API and Redis live in `default`;
  # kube-system is included so CoreDNS / the LB controller schedule.
  fargate_namespaces = var.fargate_namespaces

  # Control plane logs
  log_retention_days = var.cluster_log_retention_days

  # AWS Load Balancer Controller (reconciles TargetGroupBinding for pod -> TG
  # registration; NLB/TG are Terraform-managed in this stack).
  install_aws_load_balancer_controller       = true
  aws_load_balancer_controller_chart_version = var.aws_load_balancer_controller_chart_version

  # Datadog Cluster Agent (cluster-level visibility on Fargate — pod inventory,
  # orchestrator explorer, kube-state-metrics). DD_API_KEY is read from the SSM
  # parameter that already exists for the Lambda forwarder.
  install_datadog_cluster_agent = true
  datadog_chart_version         = var.datadog_chart_version
  datadog_api_key               = data.aws_ssm_parameter.datadog_api_key.value

  # Fargate sidecar injection: pods in these namespaces labeled
  # `agent.datadoghq.com/sidecar: fargate` (see k8s/api, k8s/redis) get a
  # datadog-agent sidecar injected so the K8s Explorer shows live pod status.
  # The listed ServiceAccounts back those pods and receive kubelet-read RBAC.
  datadog_sidecar_namespaces = ["default"]
  datadog_sidecar_service_accounts = [
    { namespace = "default", name = "internal-developer-platform-api" },
    { namespace = "default", name = "internal-developer-platform-provisioner" },
    { namespace = "default", name = "default" }, # redis runs on the default SA
  ]

  # OTel Collector prerequisites (namespace, IRSA ServiceAccount, Datadog secret
  # in the observability namespace). The Collector workload is applied from
  # k8s/otel-collector. Reuses the Datadog API key above. amp_workspace_arn is
  # left unset — the datadog exporter needs no AWS auth; set it when AMP lands.
  install_otel_collector = true

  # Fargate pod log routing — managed Fluent Bit ships pod stdout to a single
  # CloudWatch log group that we subscribe to the Datadog Lambda forwarder
  # below. Removes the need for a per-pod log-collection sidecar.
  enable_fargate_logging     = true
  fargate_log_retention_days = var.cluster_log_retention_days

  # Operator IAM principals granted cluster-admin so kubectl works from their workstations.
  cluster_admin_principal_arns = var.cluster_admin_principal_arns

  tags = local.tags
}

module "sqs" {
  source = "../../../modules/aws/sqs"

  queue_name                = var.queue_name
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size
  message_retention_seconds = var.message_retention_seconds
  receive_wait_time_seconds = var.receive_wait_time_seconds

  # Set explicitly rather than left on the module's 30s default. The consumer
  # currently only decodes the message and splits it, but it is the platform's
  # control plane: once it starts Step Functions executions, a message must stay
  # invisible long enough for that call to finish, or SQS hands the same request
  # to a second consumer and the work is started twice.
  visibility_timeout_seconds = var.queue_visibility_timeout_seconds

  # Anything reaching the dead-letter queue is a provision request that was
  # accepted with a 202 and then never carried out. Nobody finds that out
  # without an alarm.
  alarm_actions = [module.observability_alerts.topic_arn]

  # No queue policy. Both counterparties are IAM roles in this account, and a
  # same-account role is authorized by its own identity policy: the API's grant
  # is in irsa.tf here, the provisioner's in infra/live/provisioner/dev/irsa.tf.
  # A resource policy would add nothing, because an SQS policy is an additive
  # allow rather than a restriction -- it cannot stop a principal that an
  # identity policy already permits.
  #
  # It also could not name the consumer even if it were useful. SQS validates
  # principals when the policy is set, and the provisioner's role is created by
  # a stack that applies after this one, so naming it fails a fresh build with
  # "InvalidAttributeValue: Invalid value for the parameter Policy".
  #
  # The module's queue policy is for principals that cannot carry an identity
  # policy at all -- see the scaffolder's task queues, which must name
  # states.amazonaws.com.

  tags = local.tags
}

# =============================================================================
# API NLB (TERRAFORM-MANAGED)
# Kubernetes binds API pods to this target group via TargetGroupBinding.
# =============================================================================

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

# =============================================================================
# REDIS ENDPOINT SSM PARAMETER
# Redis itself runs as an in-cluster k8s Deployment (see /k8s/redis/), reachable
# via cluster DNS. Publishing the endpoint to SSM keeps the API's runtime config
# identical to the ECS-era contract.
# =============================================================================

resource "aws_ssm_parameter" "redis_endpoint" {
  name  = var.redis_ssm_parameter_name
  type  = "String"
  value = var.redis_endpoint

  tags = local.tags
}

# The Datadog Lambda forwarder (CloudWatch -> Datadog) was removed: logs now
# reach Datadog through the OTel Collector's `datadog` exporter over the OTLP
# seam, so the CloudWatch-based forwarder path is retired (see observability.tf).

# The queue's URL, which is what the AWS SDKs take — the API and the provisioner
# both resolve it at startup. Published here rather than by modules/aws/sqs:
# publishing a cross-stack contract is the live stack's job, and the module has
# no business knowing which parameter path its callers agreed on.
resource "aws_ssm_parameter" "provisioner_queue_url" {
  name  = var.ssm_parameter_name
  type  = var.ssm_parameter_type
  value = module.sqs.queue_url

  tags = local.tags
}

# The queue's ARN, for the stacks that write IAM policies against it — the
# provisioner component's IRSA role today (infra/live/provisioner/dev). The URL
# published by the sqs module is what the running services resolve at startup;
# a policy needs the ARN, and deriving one from the other in HCL would mean
# hard-coding an account id.
resource "aws_ssm_parameter" "provisioner_queue_arn" {
  name  = "/idp/shared/provisioner/queue_arn"
  type  = "String"
  value = module.sqs.queue_arn

  tags = local.tags
}
