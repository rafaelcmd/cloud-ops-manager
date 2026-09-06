variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the EKS control plane ENIs and Fargate pods"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region where the EKS cluster lives"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version of the EKS control plane"
  type        = string
  default     = "1.34"
}

variable "endpoint_private_access" {
  description = "Whether the EKS API server is reachable from inside the VPC"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server is reachable from the public internet. Open so kubectl works from operator workstations; restrict by CIDR for production."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Every principal that runs kubectl or manages Kubernetes objects needs an entry
# here: operator workstations, the deploy role, and the CI role of any stack
# whose Terraform uses the kubernetes provider. The cluster creator already has
# admin implicitly.
variable "cluster_admin_principal_arns" {
  description = "List of IAM principal ARNs to grant cluster-admin via EKS Access Entries"
  type        = list(string)
  default     = []
}

# The cluster has no EC2 nodes, so a namespace missing from this list schedules
# nothing at all.
variable "fargate_namespaces" {
  description = "Kubernetes namespaces whose pods should run on Fargate. kube-system is included so CoreDNS schedules without EC2 nodes."
  type        = list(string)
  default     = ["default", "kube-system"]
}

variable "enabled_cluster_log_types" {
  description = "EKS control plane log types to ship to CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "Retention for the EKS control-plane CloudWatch log group"
  type        = number
  default     = 7
}

variable "fargate_log_retention_days" {
  description = "Retention for the Fargate-pods CloudWatch log group (target of the aws-observability ConfigMap)"
  type        = number
  default     = 7
}

variable "enable_fargate_logging" {
  description = "Configure the aws-observability ConfigMap so Fargate-managed Fluent Bit ships pod stdout/stderr to CloudWatch Logs."
  type        = bool
  default     = false
}

# The controller reconciles TargetGroupBinding, which keeps Fargate pod IPs
# registered in the Terraform-owned target group. See aws_lb_controller.tf.

variable "install_aws_load_balancer_controller" {
  description = "Install AWS Load Balancer Controller via Helm. Required for Service type=LoadBalancer with NLB target-type=ip on Fargate."
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart"
  type        = string
  default     = "1.8.1"
}

variable "aws_load_balancer_controller_namespace" {
  description = "Namespace the AWS Load Balancer Controller runs in"
  type        = string
  default     = "kube-system"
}

# Cluster-level visibility on Fargate: pod inventory and the orchestrator
# explorer. Application telemetry does not travel this path; it goes to the OTel
# Collector over OTLP. See datadog_cluster_agent.tf.

variable "install_datadog_cluster_agent" {
  description = "Install the Datadog Cluster Agent via Helm. Requires datadog_cluster_agent_namespace to be in fargate_namespaces."
  type        = bool
  default     = false
}

variable "datadog_chart_version" {
  description = "Version of the datadog/datadog Helm chart"
  type        = string
  default     = "3.227.1"
}

variable "datadog_cluster_agent_namespace" {
  description = "Namespace the Datadog Cluster Agent runs in. Must be present in fargate_namespaces."
  type        = string
  default     = "datadog"
}

variable "datadog_api_key" {
  description = "Datadog API key consumed by the Cluster Agent (read from SSM upstream). Required when install_datadog_cluster_agent is true."
  type        = string
  default     = null
  sensitive   = true
}

variable "datadog_sidecar_namespaces" {
  description = "Namespaces hosting pods labeled for datadog-agent sidecar injection. A `datadog-secret` copy is created in each (the injected sidecar resolves it in the pod's own namespace)."
  type        = list(string)
  default     = []
}

variable "datadog_sidecar_service_accounts" {
  description = "ServiceAccounts of sidecar-labeled pods. Each is bound to a ClusterRole granting the kubelet-read access the injected agent needs on Fargate."
  type = list(object({
    namespace = string
    name      = string
  }))
  default = []
}

# Prerequisites for the telemetry pipeline every service emits into. The
# Collector workload itself is raw manifests under /k8s/otel-collector. See
# otel_collector.tf.

variable "install_otel_collector" {
  description = "Provision the OTel Collector's cluster prerequisites (namespace, IRSA ServiceAccount, Datadog secret). Reuses datadog_api_key."
  type        = bool
  default     = false
}

variable "otel_collector_namespace" {
  description = "Namespace the OTel Collector runs in. Auto-added to the Fargate profile when install_otel_collector is true."
  type        = string
  default     = "observability"
}

variable "otel_collector_service_account" {
  description = "Name of the OTel Collector ServiceAccount (must match serviceAccountName in k8s/otel-collector/deployment.yaml)"
  type        = string
  default     = "otel-collector"
}

variable "amp_workspace_arn" {
  description = "ARN of an Amazon Managed Prometheus workspace. When set, the Collector's IRSA role is granted aps:RemoteWrite to it. Leave null to use the Datadog exporter only."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
