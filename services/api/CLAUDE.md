# API Service

Go REST API and entry point of the platform: it receives resource provisioning
requests, authenticates users against Cognito, and publishes provision messages
to SQS for the downstream provisioner service.

Go version: 1.25 (see `go.mod`). Entry point: `cmd/server/main.go`.

## Commands

```bash
make build          # go build -o bin/server ./cmd/server
make test           # go test ./...
make run            # build + run
make swagger-validate  # validate docs/swagger.yaml (needs swagger-cli)
docker compose -f docker-compose.dev.yaml up   # containerized local run
```

## Architecture

Hexagonal (ports & adapters) with a composition root:

```
cmd/server/main.go              - entry point
internal/
  bootstrap/application.go      - composition root: ALL dependency wiring happens here
  domain/
    model/, valueobjects/, errors/
    ports/inbound/              - service interfaces (ResourceService, AuthService)
    ports/outbound/             - driven-side interfaces (ResourcePublisher, AuthProvider, IdempotencyStore)
  application/service/          - use-case implementations of the inbound ports
  adapters/
    inbound/http/               - router, handlers, middleware (active-requests +
                                  duration metrics, request logging, recovery,
                                  request context, standard headers, CORS, idempotency)
    outbound/sqs/               - ResourcePublisher -> SQS (dev/prod)
    outbound/kafka/             - ResourcePublisher -> Kafka (local mode)
    outbound/cognito/           - AuthProvider -> Cognito
    outbound/idempotency/       - IdempotencyStore -> Redis
  infrastructure/               - AWS SDK clients, Parameter Store, Redis client
  telemetry/                    - OTel MeterProvider + Prometheus exporter
  config/                       - env-var config (12-factor), defaults + validation
  logger/                       - logrus-backed JSON logger behind a small interface
  server/                       - HTTP server with graceful shutdown
  test/mocks/                   - hand-written fakes for ports
```

Dependency rule: `domain` depends on nothing; `application` depends on domain
ports; `adapters` implement ports; only `bootstrap` knows concrete types.
When adding a dependency, wire it in `bootstrap/application.go`, not inside
handlers or services.

## Routes

- `POST /v1/provision` — publish a provision request to the queue (SQS in
  dev/prod, Kafka in local mode); deduped by the idempotency middleware when an
  `X-Idempotency-Key` header is sent (Redis-backed).

  One request carries **both halves of the intent** — the `application` to
  scaffold and the `resources` it needs — because the resources' outputs end up
  in that application's repository. The provisioner splits them downstream; a
  split done here would put the control plane's decision in the caller. See
  `model.ProvisionRequest`.

  Two things about the payload are worth knowing before changing it:

  - `application.name` is validated by the custom `appname` tag in
    `validation.go`, which **mirrors `ApplicationName.Parse` in the scaffolder**.
    The scaffolder is the authority — anything that can write to its queue can
    reach it, so it validates again. This copy exists to turn a failed execution
    three hops away into a 400 with a usable message. If one changes, change both.
  - `request_id` is minted by the handler and ignored if supplied, by body or by
    `X-Request-Id`. It keys the scaffolder's name reservation and repository
    claim, both conditional writes on "same request id", so a caller able to
    choose it could adopt another caller's in-flight repository.
- `POST /v1/auth/signup | signin | confirm` — Cognito flows.
- `GET /v1/health` — liveness.
- `GET /metrics` — Prometheus scrape endpoint (unversioned by convention).
- `GET /v1/swagger/` — Swagger UI. The spec (`docs/swagger.yaml`) is
  hand-maintained, not generated — update it when routes change.

## Configuration

All config comes from env vars (`internal/config/config.go`); runtime values
(SQS queue URL, Cognito client ID, Redis address) are loaded from AWS Parameter
Store at boot. Key vars:

- `ENVIRONMENT` — `dev` (default), `prod`, or `local` (see below)
- `PORT` (default 8080), `LOG_LEVEL`, `SERVICE_NAME`
- `ENABLE_TRACING` — OTLP trace/log export (default true, skipped in local mode)
- `REDIS_ADDR` — overrides Parameter Store for local compose; empty + no param
  key means the idempotency layer is silently disabled
- `KAFKA_BROKERS` (comma-separated), `KAFKA_TOPIC` (default `resource-provisioning`)
  — the local-mode queue transport; must match the provisioner's topic

## Local mode

`ENVIRONMENT=local` boots the API with no AWS, Parameter Store, or Cognito. The
queue transport switches from SQS to **Kafka** (`internal/adapters/outbound/kafka`),
so `POST /v1/provision` works end-to-end offline (API -> Kafka -> provisioner) as
long as `KAFKA_BROKERS` is set — otherwise the resource route is disabled. Auth
routes still return 500 (Cognito is skipped). `/metrics`, `/v1/health`, and
swagger work regardless. Used by `docker-compose.dev.yaml`.

## Observability

All three signals are OpenTelemetry and vendor-agnostic: the app emits to an OTel
Collector (OTLP) / Prometheus and knows nothing about the backend. Datadog is one
exporter behind the Collector, not a dependency in this code. The shared OTel
resource (`internal/telemetry/resource.go`) sets `service.name` / `service.version`
/ `deployment.environment` from `SERVICE_NAME` / `SERVICE_VERSION` / `ENVIRONMENT`,
which Datadog maps onto its service/version/env unified tags. All OTLP export is
gated on `ENABLE_TRACING` and skipped in local mode (no Collector to receive it).

- **Metrics:** OpenTelemetry with a Prometheus exporter (`internal/telemetry`).
  The MeterProvider is registered as the OTel global in bootstrap, so
  instruments are created via `otel.Meter(...)` anywhere. Scraped at `/metrics`
  (pull) — in-cluster, the Collector's prometheus receiver scrapes it via the
  pod's `prometheus.io/scrape` annotations. Follow OTel semconv
  names/attributes (`semconv` v1.26.0) for new instruments.
  `RequestDurationMiddleware` records request latency on the
  `http.server.request.duration` Histogram (unit: seconds), labeled with method,
  matched route, and status code. It sits above the recovery layer so a recovered
  panic is timed and recorded as a 500. There is no separate request counter: the
  histogram's `_count` series already counts every request, so request rate is
  `rate(http_server_request_duration_seconds_count[...])`. The histogram's bucket
  boundaries are overridden to semconv seconds-scale values via a View in
  `internal/telemetry` (the SDK defaults are milliseconds-scale and would collapse
  every latency into one bucket). `ActiveRequestsMiddleware` (outermost) gauges
  in-flight requests on the `http.server.active_requests` UpDownCounter, labeled
  with method only (route/status are unknown while the request is still being
  served). Both middlewares skip the `/metrics` scrape endpoint (so Prometheus
  polling doesn't dominate the stats) and normalize the method label to a known
  set or `_OTHER` (so arbitrary request methods can't blow up cardinality).
- **Tracing:** OpenTelemetry SDK exporting spans over OTLP/gRPC to the Collector
  (`internal/telemetry/tracing.go`). The router is wrapped with `otelhttp` in
  bootstrap, which starts a server span per request from the propagated context;
  W3C trace-context + baggage propagators are installed globally. (Replaced the
  former `dd-trace-go` APM tracer.) On publish, the resource publishers
  (`outbound/sqs`, `outbound/kafka`) inject the active trace context into the
  outgoing message (SQS message attributes / Kafka headers) so the provisioner
  extracts it and continues the trace — one distributed trace across API → queue →
  provisioner. Injection is a no-op when tracing is off (local mode).
- **Logs:** logrus stays the logging API; an OTel bridge hook
  (`otellogrus`, wired in `internal/telemetry/logs.go`) mirrors every entry onto
  an OTLP/gRPC log pipeline to the Collector, carrying trace/span IDs from the
  entry context so logs correlate with traces. The hook is attached at logger
  construction via `logger.Config.Hooks`.
  `RequestLoggingMiddleware` emits one structured line per request for every
  endpoint (method, matched route, status, `duration_ms`, `request_id`), attaching
  the request context so lines correlate with the request's trace; it skips
  `/metrics` and `/v1/health` (kubelet + NLB probes would otherwise dominate log
  volume — failures surface via the probes, not logs). `RecoveryMiddleware` logs any recovered panic with a stack trace.
  Both take the logger threaded through `RouterConfig.Logger`.
  `ResourceService.SendProvisioningRequest` logs the provisioning payload
  (`request_id`, `application_name`, `template`, `resource_count`, `body`) with
  the request context attached — the
  request-body counterpart to the provisioner's received-message log, so the same
  body shows on both ends of the queue under one `trace_id`. Bodies are logged only
  on this deliberate provisioning path, not by the global middleware (which would
  capture auth-route credentials).
- **OTLP endpoint:** `OTEL_EXPORTER_OTLP_ENDPOINT` / `OTEL_EXPORTER_OTLP_INSECURE`
  (standard OTel env vars, read directly by the exporters) — not app config.

## Testing

- Standard `go test ./...`; tests use `testify/assert`, `httptest`, and the
  fakes in `internal/test/mocks` (no mock generation).
- HTTP-layer tests build routers via `NewRouterWithConfig` with nil handlers
  for routes they don't exercise.
