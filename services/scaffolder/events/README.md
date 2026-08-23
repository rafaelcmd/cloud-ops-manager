# Task fixtures

One file per message shape the scaffold state machine puts on a task queue for a
`.waitForTaskToken` task.

| Fixture | Task | Queue |
|---|---|---|
| `reserve-name.json` | `ReserveName` | state |
| `reserve-name-invalid.json` | `ReserveName` (rejected name) | state |
| `create-repository.json` | `CreateRepository` | github |

`make seed E=events/reserve-name.json` enqueues one against the state worker's
LocalStack queue; add `W=github` for the other. The queues are separate because
the Deployments are — see the security note in `../CLAUDE.md`. Seeding a fixture
onto the wrong queue is a useful thing to try: the dispatcher refuses it with
`UNKNOWN_TASK` rather than attempting work the pod has no credentials for.

`TaskToken` is a placeholder. Everything up to the callback runs for real —
deserialization, dispatch, the use case, the DynamoDB write — and then
`SendTaskSuccess` is rejected because no execution is waiting on that token, so
the message is left on the queue and redelivered. That is the designed behaviour
(see the deletion rule in `TaskQueueWorker`), not a bug: exercising the callback
end to end needs a real execution, which is the integration test's job.

**`create-repository.json` creates a real repository.** There is no local GitHub
to point at, so a worker configured with `GITHUB_ORG`, `GITHUB_APP_ID` and
`GITHUB_APP_KEY_SECRET_ARN` will call the actual API. That is only ever the
throwaway sandbox org, and the repository has to be deleted by hand afterwards —
the fixture uses a fixed name, so a second run finds its own claim replayed and
adopts the existing repository rather than failing.
