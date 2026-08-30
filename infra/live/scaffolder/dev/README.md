# Scaffolder — dev

Everything the scaffolder service owns in AWS: its DynamoDB table, a Step
Functions task queue and DLQ per worker, the Secrets Manager secret holding the
GitHub App private key and the KMS key that encrypts it, and one IRSA role plus
annotated ServiceAccount per worker.

The service itself runs as a container on the EKS cluster the `api` component
creates — see [ADR-0004](../../../../docs/adr/0004-scaffolder-runs-as-a-container-on-eks.md)
for why it is not on Lambda, and `services/scaffolder/CLAUDE.md` for the service.

## Dependencies

Apply order is `api` → `scaffolder`. This stack reads the cluster's coordinates
and OIDC provider from SSM (`/idp/shared/eks/*`), published by
`infra/live/api/dev/eks_ssm.tf`. There is no `terraform_remote_state`
read, so this workspace needs no access to the api workspace's state.

## Two workers, two roles

`local.workers` in `locals.tf` drives the queues, the roles, the policies and the
ServiceAccounts together. There are two entries, and the difference between them
is the point:

| Worker | Queue | Reads the App key |
|---|---|---|
| `state` | `...-scaffolder-state-tasks-dev` | no |
| `github` | `...-scaffolder-github-tasks-dev` | yes |

ADR-0004 traded Lambda's per-function IAM roles for a single container and
recorded the debt. This is the repayment: a pod is the smallest thing an IRSA
role attaches to, so isolating the GitHub App key means a second pod. Adding a
worker is an entry in that map; **widening the state role to reach the secret is
not an option** — it deletes the only property this structure buys.

The queues have to match the split. Two Deployments polling one queue would each
receive the other's tasks, and the IAM boundary would surface as random
`AccessDenied` instead of as a boundary.

## After the first apply

Terraform creates the secret but **not** its value, so the private key never
passes through a plan, a state file or a CI log — and the pipeline role is
explicitly denied `secretsmanager:GetSecretValue`. Put the key in by hand once:

```bash
aws secretsmanager put-secret-value \
  --secret-id internal-developer-platform-scaffolder-github-app-key-dev \
  --secret-string file://idp-scaffolder.2026-08-20.private-key.pem
```

Until that is done the github worker starts, polls, and fails every task with a
Secrets Manager error — which is the intended failure, not a misconfiguration.

## What is deliberately not here

- **The scaffold state machine.** It orchestrates the Infra Worker as well as
  this service, so it is shared infrastructure and belongs in its own component
  once the Infra Worker exists. It will target the `task_queue_arns` this stack
  publishes — one per worker, so a state routes to the pod that can serve it.
- **The template S3 bucket and its KMS key.** Not built yet; they belong here
  when they are.

## Usage

```bash
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

Or through the pipeline: `ops-infra-component.yml` with component `scaffolder`.
