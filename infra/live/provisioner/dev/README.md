# Provisioner — dev

The provisioner consumer's identity: one IAM role, assumed through the cluster's
OIDC provider, and the annotated ServiceAccount its Deployment binds to
(`k8s/provisioner/deployment.yaml`).

That is the whole stack. The consumer has no AWS resources of its own — the
queue it reads and the cluster it runs on belong to the [`api`](../../api/dev)
component — so this exists for ownership rather than for volume: a permission
the consumer needs is added here, in the service's own component, instead of
accumulating in the stack that happens to own the cluster.

## Dependencies

Apply order is `api` → `provisioner`. Everything this stack needs arrives
through SSM, published by `infra/live/api/dev`:

| Parameter | Used for |
|---|---|
| `/idp/shared/eks/cluster_name`, `/idp/shared/eks/cluster_endpoint`, `/idp/shared/eks/cluster_certificate_authority_data` | Configuring the kubernetes provider, which authenticates per run with `aws eks get-token` |
| `/idp/shared/eks/oidc_provider_arn`, `/idp/shared/eks/oidc_provider_url` | The IRSA trust policy |
| `/idp/shared/provisioner/queue_arn` | The resource the consume-side policy is written against |

There is no `terraform_remote_state` read, so this workspace needs no access to
the api workspace's state.

Because it creates a ServiceAccount in a cluster it does not own, its pipeline
role `github-actions-tf-provisioner` needs an EKS access entry — granted through
`cluster_admin_principal_arns` in `infra/live/api/dev/dev.tfvars`. Without one
the kubernetes provider fails with a bare `Unauthorized`.

## Usage

```sh
cd infra/live/provisioner/dev
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## What is deliberately not here

- **The SQS queue.** It is the seam between the API and this service; the API
  component owns it, and both services are granted one side of it.
- **The Deployment.** Kubernetes workloads are applied with `kubectl` from
  `k8s/provisioner/`, never by Terraform.
