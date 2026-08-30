# Provisioner API Gateway — Edge stack (dev)

This is **stage 3 of 3** in the dev environment. It owns the public edge:
Cognito user pool, WAF web ACL, API Gateway REST API, and the VPC Link that
points API Gateway at the in-cluster API service.

This stack depends on an NLB that is **Terraform-managed** by
`infra/live/api/dev`. The producer publishes the NLB ARN and DNS
name to SSM Parameter Store, and this stack reads those values via
`data.aws_ssm_parameter`.

## Deploy order

```
1. terraform apply (api/dev)        → EKS, SQS, Datadog forwarder
2. kubectl apply -f k8s/redis/  k8s/api/        → deploy workloads and bind API service to TG
3. terraform apply (here)                       → wires API Gateway to the NLB
```

NLB attributes are read from SSM, so this stack is decoupled from producer
state files while still avoiding runtime LB discovery races.

## Prereqs (before applying here)

```sh
# NLB details should be published by the api stack:
aws ssm get-parameter --name /internal-developer-platform/provisioner-api/nlb/arn --region us-east-1
aws ssm get-parameter --name /internal-developer-platform/provisioner-api/nlb/dns_name --region us-east-1
```

If those parameters are missing, re-run stage 1 (`api/dev`).

## Usage

```sh
cd infra/live/api_gateway/dev
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Layout
- Stack: `infra/live/api_gateway/dev`, modules from `infra/modules/aws/*`.
- State: Terraform Cloud workspace `internal-developer-platform-api-gateway-dev`.

## Files
- backend.tf: Terraform Cloud workspace configuration
- versions.tf: required Terraform and providers
- providers.tf: AWS provider only (no Kubernetes/Helm — this stack doesn't talk to the cluster)
- locals.tf: shared tags
- variables.tf: input schema
- dev.tfvars: environment values for dev
- main.tf: Cognito + WAF + API Gateway composition
- data.tf: NLB lookup via SSM parameters
- outputs.tf: API Gateway, Cognito, and NLB outputs

## Teardown order

Reverse of apply: destroy this stack first (releases the VPC Link), then
destroy the platform stack (`api/dev`) which owns the NLB/TG.
