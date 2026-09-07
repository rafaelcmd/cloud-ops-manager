# Architecture Decision Records

This directory holds the platform's Architecture Decision Records (ADRs). Each
ADR captures one significant decision that shapes the system: what we chose,
why, what we considered instead, and what the trade-offs are.

ADRs are **immutable once accepted**. If a decision is later overturned, mark
the old record as `Superseded by NNNN` and write a new ADR — don't edit the
old one. The point of an ADR log is the *history* of decisions, including
the ones that turned out wrong.

## Scope

This directory holds **platform-level** decisions — anything that crosses
service or component boundaries (API + infra + consumers, or contracts that
clients depend on).

Service-internal decisions can live closer to the code (e.g.
`services/provisioner/docs/adr/`) when they don't leak past that service.
None exist yet; create them only when the first such decision arises.

## Index

| #    | Title                                                        | Status   | Date       |
| ---- | ------------------------------------------------------------ | -------- | ---------- |
| 0001 | [Record architecture decisions](0001-record-architecture-decisions.md) | Accepted | 2026-05-03 |
| 0002 | [API-edge idempotency layer](0002-idempotency-layer.md)      | Accepted | 2026-05-03 |
| 0003 | [Redis on ECS as the idempotency store](0003-redis-on-ecs-for-idempotency-store.md) | Accepted | 2026-05-03 |
| 0004 | [Scaffolder runs as a container on EKS](0004-scaffolder-runs-as-a-container-on-eks.md) | Accepted | 2026-08-19 |
| 0005 | [Secrets Manager is reached through a VPC interface endpoint](0005-secrets-manager-vpc-interface-endpoint.md) | Proposed | 2026-09-07 |

## How to add a new ADR

1. Copy `template.md` to `NNNN-kebab-case-title.md`, picking the next free
   number.
2. Fill in **Context**, **Decision**, **Consequences**, and **Alternatives
   considered**. Keep it to roughly one page; if you need more, the decision
   probably wants to be split.
3. Set `Status: Proposed` while the PR is open. Flip to `Accepted` on merge.
4. Update the index above.
5. Commit the ADR in the **same PR** as the code that implements it. The ADR
   is the answer to "why does this PR exist?" and they should ship together.

## Format

We use a minimal Nygard-style template (see `template.md`):

- **Status** — Proposed / Accepted / Superseded by NNNN / Deprecated.
- **Context** — the forces at play. Constraints, problems, things that
  rule options out before we even pick.
- **Decision** — what we chose. Active voice, present tense ("We use X").
- **Consequences** — what becomes easier, what becomes harder, what we gave up.
- **Alternatives considered** — options we ruled out and why. This section is
  load-bearing: it's what stops the same debate from happening again in 6
  months.
