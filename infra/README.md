# Internal Developer Platform — Infrastructure

> AWS infrastructure for an event-driven internal developer platform. Terraform modules + live workspaces, deployed across decoupled stacks orchestrated by GitHub Actions over OIDC.

This directory is a self-contained Terraform monorepo. It provisions the network, container registry, identity, EKS-on-Fargate cluster, message bus, API gateway and observability that the platform's Go API and Go provisioner services run on.

It exists primarily as a study and portfolio artifact: every decision below is one I would defend in a system-design interview.

---

## What this demonstrates

- **Stack decomposition** — the platform is split across nine independently appliable Terraform stacks. Each stack owns one well-defined responsibility (network, identity, compute, etc.) and can be destroyed and recreated without touching the others.
- **State decoupling via SSM Parameter Store** — producers publish identifiers to `/idp/shared/<stack>/*`; consumers read them via `data.aws_ssm_parameter`. There are zero `terraform_remote_state` reads anywhere in `live/`. A consumer stack does not need TFC API access to a producer's state file, only IAM read on a known SSM path.
- **OIDC everywhere, no static keys** — GitHub Actions assumes a per-component AWS role via the GitHub OIDC provider. No `AWS_ACCESS_KEY_ID` lives in repository secrets.
- **EKS on Fargate** — no node groups, no EC2 patching, no Cluster Autoscaler. Workload IAM is via IRSA, bound to the cluster's OIDC issuer.
- **One-click create / destroy** — an orchestrator workflow chains the per-stack workflows in dependency order via `workflow_call`, making full-platform tear-up and tear-down a single GitHub Actions click.
- **Reusable AWS modules** — every resource lives in a module under `modules/aws/*`. Live workspaces are thin compositions: a few `module` blocks, a `data` block or two, a backend.

---

## Architecture

```
                          GitHub Actions (OIDC)
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │  Terraform Cloud workspaces  │
                  └──────────────────────────────┘
                                 │
   ┌─────────────────────────────┼─────────────────────────────┐
   │                             │                             │
   ▼                             ▼                             ▼
 shared/vpc          shared/ecr          shared/identity (Cognito)
   │                             │                             │
   ├── publishes ──────▶ /idp/shared/vpc/*    ──┐               │
   ├── publishes ──────▶ /idp/shared/ecr/*    ──┤               │
   └── publishes ──────▶ /idp/shared/identity/* ─────────────┐  │
                                                              │  │
                                                              ▼  ▼
                                                       SSM Parameter Store
                                                              │
                                  ┌───────────────────────────┤
                                  ▼                           ▼
                            api/dev                     api_gateway/dev
                       (EKS + LBC + SQS +            (API Gateway + WAF +
                        Redis SSM + DD fwd)           Cognito authorizer + VPC Link)
                                  │                           ▲
                                  ▼                           │
                          K8s API Service  ─── NLB ───────────┘
                          (provisions the NLB the
                           API Gateway VPC Link targets)
```

Cross-stack edges are SSM reads, not state reads. The only place a downstream stack pulls live AWS data instead of SSM is the gateway's `data.aws_lb.api` lookup — necessary because the NLB is provisioned by the AWS Load Balancer Controller in response to a Kubernetes Service, not by Terraform.

---

## Layout

```
infra/
├── modules/                         # reusable, parameterized Terraform modules
│   ├── aws/
│   │   ├── api_gateway/             # REST API Gateway + stage + VPC Link
│   │   ├── cognito/                 # User pool + client; publishes IDs to SSM
│   │   ├── datadog_integration/     # AWS↔Datadog integration role + log forwarder wiring
│   │   ├── ecr/                     # ECR repo + lifecycle policy; publishes URL to SSM
│   │   ├── eks/                     # EKS-on-Fargate cluster, OIDC provider, IRSA scaffolding,
│   │   │                            # CoreDNS Fargate patch, AWS Load Balancer Controller
│   │   ├── lambda/                  # Generic Lambda module (used for Datadog forwarder)
│   │   ├── oidc/                    # Generic AWS IAM OIDC provider + role
│   │   ├── sqs/                     # SQS queue + SSM publishing of URL
│   │   ├── vpc/                     # VPC, subnets, NAT-less private routing, SSM publishing
│   │   └── waf/                     # WAFv2 Web ACL for API Gateway
│   └── datadog/                     # Datadog provider integration (consumed by shared/datadog)
└── live/
    ├── shared/                      # platform-wide, environment-independent
    │   ├── vpc/                     # the only VPC
    │   ├── ecr/                     # the only image registry
    │   ├── identity/                # Cognito; standalone so other stacks need only SSM reads
    │   ├── datadog/                 # AWS↔Datadog integration + API key in SSM
    │   ├── iam-github-oidc/         # AWS role assumed by GitHub Actions
    │   └── iam-tfc-oidc/            # AWS role assumed by Terraform Cloud
    ├── api/dev/                     # EKS + SQS + Redis SSM + Datadog Lambda forwarder
    ├── provisioner/dev/             # the consumer's IRSA role + ServiceAccount
    ├── scaffolder/dev/              # scaffolder table, task queues, App key, IRSA
    └── api_gateway/dev/             # API Gateway + WAF (consumes identity + NLB)
```

Module composition stays inside the repo. Live workspaces reference modules by **relative path** (`source = "../../../modules/aws/eks"`), not by git URL — there is no push-before-apply trap and no version drift between live and module code.

---

## The nine stacks

| Stack | Workspace | Owns | Reads (SSM) |
|---|---|---|---|
| `shared/vpc` | `internal-developer-platform-shared-vpc` | VPC, 2 public + 2 private subnets, IGW, route tables, ELB role-tags | — |
| `shared/ecr` | `internal-developer-platform-shared-ecr` | ECR repo, lifecycle, repo URL in SSM | — |
| `shared/identity` | `internal-developer-platform-shared-identity` | Cognito user pool + client, identity params in SSM | — |
| `shared/datadog` | `internal-developer-platform-shared-datadog` | AWS↔Datadog integration role, Datadog API key in SSM | — |
| `shared/iam-github-oidc` | `internal-developer-platform-iam-github-oidc` | IAM role assumed by GitHub Actions via OIDC | — |
| `shared/iam-tfc-oidc` | `internal-developer-platform-iam-tfc-oidc` | IAM role assumed by Terraform Cloud via OIDC | — |
| `api/dev` | `internal-developer-platform-api-dev` | EKS cluster (Fargate), IRSA scaffolding, AWS Load Balancer Controller, SQS queue, Redis endpoint in SSM, Datadog Lambda forwarder | `/idp/shared/vpc/*`, `/idp/shared/datadog/*` |
| `provisioner/dev` | `internal-developer-platform-provisioner-dev` | The provisioner consumer's IRSA role and ServiceAccount. No service of its own: the queue and the cluster belong to `api/dev`, and it reaches both through SSM. | `/idp/shared/eks/*`, `/idp/shared/provisioner/queue_arn` |
| `api_gateway/dev` | `internal-developer-platform-api-gateway-dev` | REST API Gateway, VPC Link, Cognito authorizer, WAF Web ACL | `/idp/shared/identity/*`, `data.aws_lb` (NLB by name) |
| `scaffolder/dev` | `internal-developer-platform-scaffolder-dev` | Scaffolder DynamoDB table, one task queue + DLQ per worker, GitHub App key secret + KMS key, two IRSA roles and ServiceAccounts | `/idp/shared/eks/*` |

The two `iam-*-oidc` stacks are bootstrap; they exist so every other stack can authenticate without long-lived credentials. They are deliberately **not** part of the orchestrator chain — the orchestrator itself depends on them.

---

## Key engineering decisions

### 1. SSM Parameter Store as the cross-stack contract

Originally the project used `data.terraform_remote_state` to share IDs between stacks. That created hard coupling — every consumer needed TFC API access to every producer, and circular references (the gateway referenced the EKS stack via the API stack, which referenced the gateway via Cognito) became latent bugs that only surfaced during destroy.

The migration to SSM:

```hcl
# Producer (modules/aws/vpc/ssm.tf)
resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/idp/shared/vpc/private_subnet_ids"
  type  = "StringList"
  value = join(",", [for s in aws_subnet.private : s.id])
}

# Consumer (live/api/dev/data.tf)
data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/idp/shared/vpc/private_subnet_ids"
}
# usage: split(",", data.aws_ssm_parameter.private_subnet_ids.value)
```

The contract is just a path. Anything — Terraform, a CI script, a Lambda — can resolve it.

### 2. Cognito as a standalone shared stack

Cognito used to live inside the `api_gateway` stack because the gateway needed it as the authorizer. But the API workload also needs the user pool ARN for IRSA scoping, and shoving Cognito into `api_gateway` made the API stack depend on the gateway stack — which already depended on the API stack via the NLB. Promoting Cognito to its own `shared/identity` stack collapses the cycle into a strict DAG.

### 3. EKS on Fargate with IRSA, no node groups

The platform's workload pattern (long-tail traffic, infrequent invocations) is poorly served by EC2 worker nodes — you pay for idle capacity. Fargate per-pod pricing is the right cost model. The trade-offs encoded in the EKS module:

- **CoreDNS patch baked in** — EKS ships CoreDNS with `eks.amazonaws.com/compute-type: ec2`, which prevents Fargate scheduling. A `kubernetes_annotations` resource strips it on apply.
- **AWS Load Balancer Controller installed via Helm** with an IRSA-backed ServiceAccount and an explicit IAM policy (no AWS-managed policy — minimum permissions matched to the controller's needs).
- **Access Entries API** (not the legacy `aws-auth` ConfigMap) for granting cluster-admin to operator IAM principals.

### 4. The NLB is a Kubernetes resource, not a Terraform resource

The API's NLB is provisioned by the AWS Load Balancer Controller in response to `k8s/api/service.yaml`. The gateway stack reads it back by name using `data.aws_lb` — Terraform never owns the NLB. This keeps the deploy story (`kubectl apply -f k8s/api/service.yaml`) and the infrastructure story (`terraform apply`) cleanly separated.

### 5. Tight per-resource IAM scoping where it costs nothing

Module IAM policies use concrete ARNs (`aws_ecr_repository.this.arn`, `aws_sqs_queue.this.arn`) rather than `Resource = "*"` whenever the producer Terraform has the ARN in scope. The exception is the AWS Load Balancer Controller policy, which mirrors the upstream-recommended policy — those `*`s are tag-conditioned (`elbv2.k8s.aws/cluster`).

---

## SSM parameter contract

| Path | Type | Producer | Consumers |
|---|---|---|---|
| `/idp/shared/vpc/id` | String | `shared/vpc` | `api/dev` |
| `/idp/shared/vpc/cidr_block` | String | `shared/vpc` | — |
| `/idp/shared/vpc/public_subnet_ids` | StringList | `shared/vpc` | — |
| `/idp/shared/vpc/private_subnet_ids` | StringList | `shared/vpc` | `api/dev` |
| `/idp/shared/identity/user_pool_id` | String | `shared/identity` | (future workloads) |
| `/idp/shared/identity/user_pool_arn` | String | `shared/identity` | `api_gateway/dev` |
| `/idp/shared/identity/user_pool_client_id` | String | `shared/identity` | (future workloads) |
| `/idp/<project>/<env>/datadog/api_key` | SecureString | `shared/datadog` | `api/dev` |
| `/idp/<project>/<env>/ecr/<repo>/repository_url` | String | `shared/ecr` | `cd-api.yml` (CI) |
| `/idp/shared/provisioner/queue_arn` | String | `api/dev` | `provisioner/dev` |
| `/INTERNAL_DEVELOPER_PLATFORM/PROVISIONER_QUEUE_URL` | String | `api/dev` (SQS module) | Go API runtime |
| `/INTERNAL_DEVELOPER_PLATFORM/COGNITO_CLIENT_ID` | String | `shared/identity` (Cognito module) | Go API runtime |
| `/INTERNAL_DEVELOPER_PLATFORM/REDIS_ADDR` | String | `api/dev` | Go API runtime |

The two namespaces reflect a deliberate split:

- `/idp/shared/*` — cross-Terraform-stack contracts. Producers and consumers are both Terraform.
- `/INTERNAL_DEVELOPER_PLATFORM/*` — Terraform-to-runtime contracts. Consumer is a running service reading SSM at boot.

---

## CI / CD

Full pipeline map — triggers, IAM roles, approval gates, runbook — is in
[`.github/workflows/README.md`](../.github/workflows/README.md). The infra-relevant
part, in two layers:

**Reusable Terraform workflow** (`.github/workflows/_terraform.yml`) — one parameterized pipeline for every stack, taking `component` (vpc, ecr, datadog, identity, api, api-gateway) and `action` (apply, destroy) as inputs. It maps the component to its working directory and var-file, then runs:

1. `actions/checkout`
2. `hashicorp/setup-terraform` with `cli_config_credentials_token` (TFC token)
3. `terraform init` / `fmt -check -recursive` / `validate` / `plan` / `apply` (or `plan -destroy` / `destroy`)

That `fmt -check` is scoped to the component's own directory. Formatting across all of `infra/` — including the shared modules, which no single component's run reaches — is enforced by the `terraform-fmt` job in `ci-infra-policy.yml`.

Component-specific post-apply steps (CoreDNS restart for `api`, Datadog agent image mirror for `ecr`) live behind `if:` conditions in the same file. Manual single-stack runs go through `ops-infra-component.yml`, a thin `workflow_dispatch` wrapper with component/action dropdowns.

**Orchestrators** (`ops-platform-up.yml`, `ops-platform-down.yml`) — chain the stacks in dependency order using `needs:`, each job calling the reusable workflow:

```yaml
jobs:
  shared-vpc:
    uses: ./.github/workflows/_terraform.yml
    with: { component: vpc, action: apply }
    secrets: inherit
  shared-identity:
    needs: [shared-vpc]
    uses: ./.github/workflows/_terraform.yml
    with: { component: identity, action: apply }
    secrets: inherit
  provisioner-api:
    needs: [shared-vpc, shared-ecr, shared-datadog]
    uses: ./.github/workflows/_terraform.yml
    with: { component: api, action: apply }
    secrets: inherit
  ...
```

Destroy requires typing `destroy` into a confirmation input — the workflow fails before doing anything if the string doesn't match. Cheap insurance against a stray click.

AWS authentication is OIDC end-to-end:

- No long-lived AWS keys exist in CI; every job exchanges a GitHub OIDC token for temporary credentials via `aws-actions/configure-aws-credentials`.
- Each Terraform component assumes its own role, `github-actions-tf-<component>`, carrying only the services that component provisions (`infra/live/shared/iam-github-oidc/policy_*.tf`). Workflows build the ARN from the component name plus the `AWS_ACCOUNT_ID` variable, so a new component needs no new repo configuration.
- Workload deploys assume `github-actions-deploy` — SSM reads, ECR push, and cluster auth only. It appears in `cluster_admin_principal_arns` so EKS grants it kubectl access through an access entry.
- Pull-request plans assume `github-actions-oidc-plan-role`, which holds `ReadOnlyAccess`: unmerged code can compute a diff but never mutate AWS.
- Trust policies allow three subjects — `...:ref:refs/heads/main`, `...:environment:dev` and `...:environment:dev-auto` — so write-capable credentials are only issued to jobs on `main` or inside a deployment environment (`dev-auto` replaces `dev` when `DISABLE_DEPLOYMENT_APPROVALS` is set). Pull requests match neither.
- Component policies authorize creation on the `Project` request tag and mutation on the `Project` resource tag, so a role cannot modify resources outside this project even within its own services.
- Terraform Cloud holds state only. Runs execute on the GitHub runner in Local execution mode, so the identity applying a stack is always its `github-actions-tf-<component>` role — never a single shared role across every stack. The `shared/iam-tfc-oidc` stack predates this and is retained for the remote-run path; nothing currently uses it.
- A stack that manages Kubernetes objects needs an EKS access entry for its own role, granted through `cluster_admin_principal_arns` in `api/dev`. Without one the kubernetes provider fails with a bare `Unauthorized`, which says nothing about IAM.

---

## Running it

### Prerequisites (one-time)

1. AWS account.
2. Terraform Cloud organization (`internal-developer-platform-org`).
3. Apply `shared/iam-tfc-oidc` and `shared/iam-github-oidc` once, locally or by hand, to bootstrap the OIDC trust.
4. Create each TFC workspace listed in [the nine stacks table](#the-nine-stacks), pointed at this repo with the matching working directory. **Set its execution mode to Local.** Terraform runs on the GitHub runner under the per-component `github-actions-tf-<component>` role; a workspace left on Terraform Cloud's default of Remote executes on TFC's infrastructure instead, under a different identity, and fails with *"No valid credential sources found"*. Workspaces are not managed as code, so nothing in this repo enforces this.
5. Populate GitHub repository secrets: `TF_API_TOKEN`, `DD_API_KEY`. Populate variables: `AWS_REGION`, `AWS_ROLE_ARN`, `AWS_ACCOUNT_ID`.

### Full platform up

GitHub → Actions → **Orchestrate - Create Full Infrastructure** → Run.

End-to-end takes ~15–20 minutes; the EKS control plane dominates.

### Full platform down

GitHub → Actions → **Orchestrate - Destroy Full Infrastructure** → enter `destroy` in the confirmation field → Run.

### Single stack

Each stack workflow is still independently dispatchable. Useful when iterating on, say, the API Gateway module without touching the cluster.

### Local dev

Module work doesn't need a workspace. From any `live/<stack>/` directory:

```bash
terraform init
terraform validate
terraform plan -var-file=dev.tfvars   # if a tfvars file exists
```

Authoring inside a module is just editing files under `modules/aws/<name>/` — live workspaces pick up changes on next plan because sources are relative.

---

## What's intentionally not here

Decisions I made for scope, with the trade-off I'd revisit at production scale:

- **No multi-environment promotion** (`staging/`, `prod/`). The directory pattern (`live/<stack>/dev/`) is ready for it; the stacks just don't have siblings yet.
- **No remote backend encryption with a customer-managed KMS key** — TFC handles state at rest with its own KMS. Acceptable for now.
- **No drift detection cron**. A scheduled `terraform plan` would alert on out-of-band changes; not wired up.
- **No cost budget alarms / per-stack AWS Budgets**. The whole platform stays under the AWS free-tier ceiling for short-lived study sessions; that wouldn't survive contact with production.
- **Single AWS account, single region**. No cross-account or DR posture.
- **The IRSA wiring for the Go API was reverted during the SSM refactor** and will be re-introduced under `live/api/dev/` once the SSM-based identity contract has been validated end-to-end.

---

## What I learned building this

- A Terraform "monolith" is much easier to reason about than a graph of remote-state references. Move shared values to a flat key/value store and most of your hidden coupling disappears.
- Fargate + IRSA collapses three otherwise-significant operational concerns (node lifecycle, instance role sprawl, IMDS access) into zero work. It's the right default for low-volume internal platforms.
- The AWS Load Balancer Controller's documented IAM policy is non-negotiable — every `Action` it lists exists because something broke without it. Trimming the policy is a false economy.
- `workflow_call` + `secrets: inherit` is enough to build a real orchestrator without pulling in a workflow engine. The dependency graph is just `needs:`.
