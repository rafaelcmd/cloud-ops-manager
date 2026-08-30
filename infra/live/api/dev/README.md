# Provisioner API — Platform stack (dev)

This is **stage 1 of 3** in the dev environment. It owns the long-lived platform
plumbing: EKS, SQS, the Redis SSM endpoint pointer, and the Datadog forwarder.

Stages 2 and 3 (Kubernetes workloads → API Gateway edge) are deliberately
applied separately because the NLB the edge needs is created by the AWS Load
Balancer Controller in response to the k8s `Service` — it doesn't exist at the
moment Terraform plans this stack.

## Deploy order

```
1. terraform apply (here)                       → creates EKS, SQS, Datadog forwarder
2. kubectl apply -f k8s/redis/  k8s/api/        → LB controller creates the NLB
3. terraform apply (api_gateway/dev)→ wires API Gateway to the NLB
```

## Layout
- Stack: `infra/live/api/dev`, modules from `infra/modules/aws/*`.
- Owns the cluster and the queue, and publishes their coordinates to SSM
  (`eks_ssm.tf`, `/idp/shared/provisioner/queue_arn`). The services that run on
  them own their own identities elsewhere: `infra/live/provisioner/dev` and
  `infra/live/scaffolder/dev` both read those parameters and create their own
  IRSA roles. The API's own IRSA stays here, in `irsa.tf`, because the API is
  this stack's workload.
- State: Terraform Cloud workspace `internal-developer-platform-provisioner-api-dev`.

## Usage
```sh
cd infra/live/api/dev
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

After apply, configure kubeconfig and ship the workloads:

```sh
aws eks update-kubeconfig \
  --name internal-developer-platform-cluster \
  --region us-east-1

kubectl apply -f ../../../../k8s/redis/
kubectl apply -f ../../../../k8s/api/

# Wait until the NLB is ready
kubectl get svc -w
```

Then proceed to `infra/live/api_gateway/dev`.

## Files
- backend.tf: Terraform Cloud workspace configuration
- versions.tf: required Terraform and providers
- providers.tf: AWS / Kubernetes / Helm provider config (kube + helm are needed by the EKS module to install the LB controller)
- locals.tf: shared tags
- variables.tf: input schema (no env defaults)
- dev.tfvars: environment values for dev
- main.tf: stack composition using local modules
- data.tf: remote states and SSM data
- outputs.tf: stack outputs (consumed by operators and the edge stack)

## Notes
- Keep secrets out of tfvars; use SSM/Secrets Manager for sensitive values.
- Prefer `terraform fmt`, `terraform validate`, and linting (tflint/tfsec) before commits.
