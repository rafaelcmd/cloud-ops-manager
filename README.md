# Internal Developer Platform

> A cloud-native, event-driven platform that lets engineering teams self-service cloud
> infrastructure — provisioning resources on demand through a single REST API.

Built as a microservices system on AWS, this project demonstrates production-grade
patterns in distributed systems design: asynchronous messaging, service decoupling,
and infrastructure-as-code.

---

## Why this project

Platform engineering teams spend enormous effort giving developers a paved road to cloud
resources without sacrificing control or visibility. This IDP tackles that problem end to end:

- **Self-service provisioning** — developers request resources through a single REST API instead of filing tickets or writing Terraform by hand.
- **Event-driven decoupling** — the API never blocks on slow cloud operations; work is handed off through a durable message queue.
- **Production-grade observability** — metrics, logs, and distributed traces flow through an OpenTelemetry Collector into Datadog, so every request is traceable end to end.

---

## Architecture

An event-driven system designed for resilience and independent scaling.

```
                         ┌──────────────────┐
   Developer ──HTTP──▶   │       API        │   (Go 1.25)
                         │  REST interface  │
                         └────────┬─────────┘
                                  │ publish
                                  ▼
                         ┌──────────────────┐
                         │     AWS SQS      │   durable message queue
                         └────────┬─────────┘
                                  │ consume
                                  ▼
                         ┌────────────────┐
                         │  Provisioner   │
                         │   (Go 1.25)    │
                         │ creates cloud  │
                         │   resources    │
                         └────────────────┘
```

**Message flow:** `API → SQS → Provisioner`

Decoupling the write path (API) from the worker (Provisioner) via SQS means each
service scales, deploys, and fails independently — a core tenet of reliable distributed systems.

---

## Tech Stack

| Domain            | Technologies                                              |
|-------------------|-----------------------------------------------------------|
| **Languages**     | Go (API, Provisioner)                                     |
| **Compute**       | AWS EKS on Fargate, Kubernetes                            |
| **Networking**    | VPC with private subnets, interface + gateway VPC endpoints, NAT gateway |
| **Messaging**     | AWS SQS (production), Kafka (local dev)                   |
| **Infra as Code** | Terraform (`modules/` + `live/` pattern)                 |
| **Auth**          | AWS Cognito                                               |
| **Observability** | Datadog, AWS X-Ray                                        |
| **CI/CD**         | GitHub Actions                                            |

---

## Engineering Highlights

- **Asynchronous, at-least-once processing** built on SQS for durability and back-pressure tolerance.
- **Infrastructure as code** — the entire AWS footprint (EKS, SQS, Cognito) is reproducible through Terraform.
- **Runs serverless-ly** on EKS + Fargate — no node management, pay-per-pod.
- **Private-by-default networking** — workloads in the private subnets reach AWS services (SQS, ECR, CloudWatch Logs, SSM, S3 and Secrets Manager) over VPC endpoints rather than the public internet. The NAT gateway remains for third-party services that have no AWS-network path, such as GitHub and Datadog.
- **First-class observability** with Datadog metrics and distributed tracing via AWS X-Ray.

---

## Repository Layout

```
services/
  api/                Go REST API — accepts requests, publishes to SQS
  provisioner/        Go service — provisions cloud resources from SQS
infra/                Terraform modules and live environments
k8s/                  Kubernetes manifests
k6/                   Load-testing scripts
.github/workflows/    CI/CD pipelines — see .github/workflows/README.md
.github/actions/      Composite actions shared by the workflows
```

Workflow filenames encode when they run: `ci-` on pull requests, `cd-` to ship,
`ops-` for manual operator actions, `_` for internal reusable pipelines.
[`.github/workflows/README.md`](.github/workflows/README.md) documents the
triggers, IAM roles, approval gates and a from-scratch runbook.

---

## Running Locally

Spin up the full stack (Kafka + Zookeeper + services + OTel Collector) with Docker Compose:

```bash
docker compose -f docker-compose.dev.yaml up
```

**Observability locally:** an OpenTelemetry Collector receives OTLP from the
services and scrapes the API's `/metrics`. Inspect the pipeline with:

```bash
docker compose -f docker-compose.dev.yaml logs -f otel-collector  # telemetry (debug exporter)
curl http://localhost:8889/metrics                                # collected metrics
```

Run individual services:

```bash
# API (Go)
cd services/api && go run cmd/server/main.go

# Provisioner (Go)
cd services/provisioner && go run cmd/consumer/main.go
```

Run the test suites:

```bash
cd services/api && go test ./...
cd services/provisioner && go test ./...
```

---

## Roadmap

- **Multi-cloud provisioning** — the API already validates requests for AWS, Azure, and GCP; the Provisioner currently targets AWS, with the other providers planned.
- **Cost tracking** — per-resource spend reporting, making cost a first-class signal alongside provisioning.
