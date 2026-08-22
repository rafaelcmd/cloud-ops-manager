# Internal Developer Platform

Monorepo for an internal developer platform that provisions cloud resources.

## Architecture

Event-driven, multi-service platform on AWS (EKS, SQS, Cognito):

1. **API** (`/services/api`) — Go 1.25 REST API. Receives provision requests — one request carries both the application to scaffold and the cloud resources it needs — and publishes them to SQS.
2. **Provisioner** (`/services/provisioner`) — Go 1.25 service and the control plane. Consumes SQS messages and splits each request into the work each downstream worker owns: the repository half for the scaffolder, the resources half for the infra worker.
3. **Scaffolder** (`/services/scaffolder`) — .NET 10 container on EKS. Owns the repository domain: creates GitHub repos from golden-path templates and wires their CI/CD. Consumes Step Functions `.waitForTaskToken` messages off its own SQS queues, as two Deployments of one image split by what they are trusted with — only the `github` one can read the GitHub App private key. **Under construction** — the solution, the `ReserveName` and `CreateRepository` tasks, the GitHub App adapter, the image and its Terraform component exist; nothing is deployed yet, and nothing upstream calls it.

Message flow: API → SQS → Provisioner → Step Functions → task workers

The request contract is defined in `services/api/internal/domain/model/resource.go` and
**duplicated** in `services/provisioner/internal/provision/request.go`. Separate modules and
separate deployables, so a shared struct would make a field rename in one a compile break in the
other — the coupling a queue exists to remove. Change them together.

Planned but not yet created: an **Infra Worker** (Go) that executes infrastructure-as-code as a
`.waitForTaskToken` task in the same state machine. Until it exists, the provisioner is still a
bare consume loop and no state machine is deployed.

## Conventions

- Each service has its own `CLAUDE.md` with service-specific details — read it before working on that service.
- When a change alters a service's architecture, commands, or conventions, update that service's CLAUDE.md in the same commit.
- Go services use standard `cmd/` and `internal/` layout.
- Infrastructure follows Terraform `modules/` + `live/` pattern, with no exceptions: every AWS
  resource in the platform is Terraform-owned, and every workload is a container deployed with
  `kubectl`. The scaffolder was briefly a SAM/Lambda exception; see
  [ADR-0004](docs/adr/0004-scaffolder-runs-as-a-container-on-eks.md) for why it is not any more.
- Services own their own data. No service reads another service's table or database.
