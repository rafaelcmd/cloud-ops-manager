# ADR-0004: Scaffolder runs as a container on EKS, not on Lambda

- **Status:** Accepted
- **Date:** 2026-08-19
- **Deciders:** Rafael Costa
- **Related:** ADR-0003 (Redis on ECS as the idempotency store)

## Context

The scaffolder owns the repository domain of the platform: it reserves an
application name, creates a GitHub repository from a golden-path template,
injects the infrastructure outputs the Infra Worker produced, wires CI/CD and
records what it built. Each of those is a task state in the scaffold state
machine.

It was originally built as .NET Lambda functions deployed with AWS SAM, on two
stated grounds: the work is spiky and event-driven, and keeping it off the
cluster stops a GitHub outage from consuming pod capacity. That introduced a
second IaC tool into a repo whose stated convention is Terraform, and the
exception needs to hold up on its own.

Three facts about the platform as actually built undermine it.

**The cluster is EKS on Fargate.** Every pod gets its own microVM with its own
CPU and memory limits. A scaffolder pod stuck in rate-limit backoff cannot
starve the API pod, because there is no shared node capacity to contend for.
The isolation argument holds on shared EC2 nodes; it does not hold here.

**The OTel Collector runs in-cluster.** The platform's telemetry rule is
vendor-agnostic OpenTelemetry, and the API and provisioner both export OTLP to
`otel-collector.observability.svc.cluster.local:4317`, which forwards to
Datadog. Lambda cannot reach that endpoint without being VPC-attached. The
Lambda design conceded the point and exported to X-Ray and CloudWatch instead —
so a scaffold request would have produced a trace that ran through Datadog for
API → SQS → provisioner and then fell into a different backend for the seven
steps where the interesting work happens.

**The Infra Worker is already a container consuming task tokens.** The
`ProvisionInfra` state is a `.waitForTaskToken` task handled by a Go pod: Step
Functions puts the token on an SQS queue, the worker does slow work and calls
`SendTaskSuccess` with its outputs. Whatever plumbing that needs is being
written for this platform regardless, so "Lambda is the natural Step Functions
task type" is not a differentiator.

The idle-cost argument survives but is small: the cluster is already running,
and one more Fargate pod is roughly $15/month.

## Decision

We run the scaffolder as a container on the same EKS Fargate cluster as the API
and the provisioner. All of its infrastructure is Terraform-owned. SAM and
CloudFormation are removed from the repository entirely.

Concretely:

- `Scaffolder.Functions` is replaced by `Scaffolder.Worker`, a .NET generic
  host whose `BackgroundService` long-polls the scaffolder task queue, resolves
  the task name to a use case, and reports back with `SendTaskSuccess` /
  `SendTaskFailure`. It is a composition root, exactly as the Lambda handlers
  were — the dependency rule is unchanged and still enforced by
  `DependencyRuleTests`.
- `Scaffolder.Domain`, `Scaffolder.Application` and `Scaffolder.Infrastructure`
  are untouched. Making the runtime a detail of the outermost layer is what the
  hexagonal layout was for, and this is the first time that has been cashed in.
- A new `scaffolder` Terraform component (`infra/live/scaffolder/dev`) owns the
  DynamoDB table, the task queue and its DLQ, the IRSA role, the annotated
  ServiceAccount, and the SSM parameters the pod reads at startup.
- The EKS stack publishes its cluster coordinates and OIDC provider to SSM under
  `/idp/shared/eks/*`, so the new component resolves them the same way every
  other consumer resolves cross-stack values — no `terraform_remote_state`.
- Deployment is `cd-scaffolder.yml`: build the image, push to the shared ECR
  repository with a `scaffolder-<sha>` tag, `kubectl apply`, wait for rollout.
  Identical in shape to `cd-provisioner.yml`.
- The scaffold state machine, when it is built, belongs to Terraform like every
  other shared resource. It is not part of this decision and does not exist yet.

This decision covers the scaffolder only. It does not reopen the choice of .NET,
of DynamoDB single-table design, or of a GitHub App over a PAT.

## Consequences

**Easier.** One deployment model across all three services: one CI pattern, one
rollout mechanism, one Terraform state layout, one way to answer "what changes
if I apply everything". Telemetry needs no special case — the same OTel SDK
pointed at the same Collector puts a scaffold on the same distributed trace as
the request that triggered it. The local loop is `docker compose up` against
LocalStack rather than `sam local invoke`, which is what the other two services
already do. A whole class of toolchain friction disappears with SAM: the
`Amazon.Lambda.Tools` global tool that is not on `PATH`, the
`aws-lambda-tools-defaults.json` that duplicates the target framework because
that tool text-parses the `.csproj`, the x86_64-over-arm64 compromise made so
`sam local invoke` would run without qemu binfmt, and the CloudFormation
intrinsics that no schema-aware editor can typecheck.

**Harder.** We lose per-function IAM. On Lambda, `ReserveNameFunction` held
`dynamodb:PutItem` and structurally could not read the GitHub App private key.
One pod means one IRSA role covering every task the worker dispatches, so that
boundary becomes a code convention rather than an infrastructure guarantee.
This is a real regression and the mitigation is to split into two Deployments
with two IRSA roles — one for state operations, one for GitHub operations —
when the GitHub adapter lands. Until then the worker holds only DynamoDB and
Step Functions permissions, so the exposure is theoretical, but it must not be
forgotten.

> **Done.** The GitHub adapter landed with `CreateRepository`, and the split came
> with it: `scaffolder-state` and `scaffolder-github` run the same image with
> separate IRSA roles, and only the latter can read the App private key. It cost
> a second SQS queue — two Deployments on one queue would each receive the
> other's tasks, so the routing has to follow the trust boundary. See
> `local.workers` in `infra/live/scaffolder/dev/locals.tf`.

We also give up scale-to-zero, and the automatic safe-deploy machinery that
`AutoPublishAlias` plus `DeploymentPreference: Canary10Percent5Minutes` gave for
two lines of YAML. A Kubernetes rolling update with readiness gating is the
replacement, and it is weaker: there is no alarm-driven automatic rollback.

**What we gave up outside the architecture.** This service was the study vehicle
for AWS DVA-C02, and its build plan was organised by exam domain. Removing
Lambda and SAM removes first-hand coverage of Lambda execution contexts,
versions and aliases, CodeDeploy canary configurations, and the
`AWS::Serverless` transform — most of Domain 3. That coverage now has to come
from somewhere else. It is recorded here because it was a genuine input to the
original decision and should not silently disappear from the record.

## Alternatives considered

- **Keep Lambda, keep SAM (the status quo).** Rejected because the two reasons
  given for it do not survive contact with the platform as built: Fargate
  already provides the isolation, and the in-cluster Collector makes Lambda the
  one component that cannot participate in the platform's own tracing.

- **Keep Lambda, deploy it with Terraform instead of SAM.** This removes the
  second IaC tool: CI runs `dotnet lambda package`, uploads the zip to S3 under
  a content hash, and `terraform apply` points `aws_lambda_function.s3_key` at
  it. Rejected because it fixes the tooling complaint and none of the telemetry
  one — the trace still fragments — while giving up local invocation entirely.

- **Keep SAM for the functions, move only the long-lived resources to
  Terraform.** The narrower fix: the table, bucket, secret and state machine go
  to Terraform, and `template.yaml` shrinks to a build-and-deploy manifest for
  code. Rejected for the same reason — it makes the boundary defensible but
  leaves the scaffolder outside the platform's observability pipeline, which was
  the decisive problem.

- **Run the scaffolder as a Kubernetes Job per scaffold request.** Closer to the
  spiky shape of the work than a long-lived Deployment. Rejected as premature:
  it needs a controller to translate a task token into a Job and reconcile
  failures, which is meaningful machinery to own for a workload measured in
  requests per day. A long-polling Deployment is simpler and can be revisited.

## When to revisit

- If scaffold throughput ever makes a single-replica consumer the bottleneck.
  Scaling out needs the per-task conditional writes to be in place first, since
  at-least-once delivery is the whole reason they exist.
- If the platform gains a compliance requirement for per-operation credential
  isolation before the two-Deployment split lands, that split becomes urgent
  rather than planned.
- If the platform ever moves off Fargate onto shared EC2 nodes, the pod-capacity
  isolation argument for keeping this workload off the cluster becomes real
  again.
