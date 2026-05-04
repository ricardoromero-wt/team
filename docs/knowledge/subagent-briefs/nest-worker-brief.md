# Nest Worker Subagent Brief

> Dispatch contract for Cloud Run workers built on NestJS. Primary target: `apps/vcon-worker`.

A worker is structurally similar to a Nest HTTP API (same NestJS, Prisma, GCP SDKs) but its job is to consume work — pub/sub messages, Cloud Tasks, scheduled triggers, or polled queues — and produce side effects. The verification surface is therefore different from an API: idempotency, retry semantics, and concurrency matter more than request/response shape.

## Scope & boundaries

**Owns**:
- Controllers (often HTTP entrypoints from Cloud Run that receive Pub/Sub push or Cloud Tasks)
- Application services that perform the work
- Domain logic, repositories (Prisma), external service clients
- Worker-thread scaffolding (e.g. `worker-thread.ts`) and concurrency configuration
- Unit and integration tests

**Does not own**:
- Prisma schema changes — shared with `aqm-api`, requires Team review
- Pub/Sub topic/subscription topology, Cloud Tasks queue config, Cloud Scheduler crons — those live in Terraform/IaC and require Team review
- The producer side of the queue — if a vcon-worker change requires a new message shape, Team writes the contract assertion before dispatch
- Cold-start tuning at the Cloud Run service level (CPU/memory/min-instances) — out of scope

## Input fields (Team's brief must include)

1. **Goal** — what changes, why, what observable side effect proves done (e.g. "after consuming a vCon message, a row with status=processed appears in `evaluation_run`")
2. **Workspace** — exact path, e.g. `apps/vcon-worker`
3. **Trigger shape** — how work arrives: HTTP push, Pub/Sub, Cloud Tasks, scheduled. Sample message payload required
4. **Touchpoints** — expected modules
5. **Cross-package touchpoints** — explicit list of files outside `apps/<worker-name>` that this work authorizes the implementer to write. Default is none. When the work changes the shape of a consumed message, a produced message, or any persisted record consumed by another service, this section must include:
   - Source-of-truth Zod schema in `packages/common-types/src/<domain>/schemas/` if one exists for the affected message or contract
   - Test fixtures in producer or consumer workspaces (`apps/*-api`, `apps/*-web`, other workers) that build mocks against the shared schema and would fail validation without an update
   The Team dispatching the brief is responsible for identifying these via the researcher's cross-package scan; the implementer does not infer them. If a touchpoint is discovered mid-work that wasn't authorized, the implementer STOPS and surfaces it in OPEN QUESTIONS.
6. **Acceptance criteria** — bulleted, expressible as test assertions on side effects
7. **Idempotency requirement** — whether the work must be safe under redelivery. If yes, the brief specifies the dedupe key and storage
8. **Concurrency expectations** — whether `WORKER_THREAD_COUNT` × `CONCURRENT_EVALUATIONS_PER_THREAD` matters for the change; whether new code is thread-safe
9. **Constraints** — what NOT to change (e.g. "do not change retry policy", "do not introduce a new external dependency")
10. **Test plan** — unit tests for domain logic, integration tests for the consume → side-effect path
11. **Failure-mode plan** — what happens on transient failure (retry), permanent failure (dead-letter or log + drop), partial failure (rollback or compensate)
12. **Out of scope**

## Mandatory verification gates

```bash
cd apps/<worker-name>

# 1. Prisma client current
pnpm run prisma:generate

# 2. Lint
pnpm run lint

# 3. Type-check
pnpm run type-check

# 4. Tests (unit + integration)
pnpm run test
# Substantive changes:
pnpm run test:coverage

# 5. e2e if applicable
pnpm run test:e2e

# 6. Build
pnpm run build
```

**Worker-specific assertions on top of the standard gates**:

- **Idempotency proof**: if the brief declared an idempotency requirement, the subagent must add a test that delivers the same message twice and asserts the side effect happened exactly once.
- **Retry behavior proof**: if the brief specified retry semantics, the subagent must add a test that simulates a transient failure on first attempt and asserts the second attempt succeeded.
- **Concurrency proof**: if the change touches state shared across the threaded worker, the subagent must add a test or document why the change is thread-safe by inspection.

**Gate-skipping rule**: same as other briefs — silent skip is a contract violation. The worker-specific assertions cannot be skipped just because they are "harder to test"; the brief must specify the test approach (real Postgres, in-memory mock, Pub/Sub emulator) before dispatch.

**Pre-flight gotchas**:
- `vcon-worker` boots a NestJS HTTP listener (`app.listen(port)`); it is HTTP-fronted even though semantically a worker. Tests can use supertest.
- `worker-thread.ts` is excluded from coverage in the workspace's Jest config — coverage numbers do not reflect threaded code paths. Threaded code requires explicit test design.
- `WORKER_CONCURRENCY` and `WORKER_THREAD_COUNT` env vars change behavior at runtime. Test fixtures should pin them.

## Evidence shape (subagent returns)

Same as Nest API brief, with these worker-specific additions:

- **Trigger evidence**: how the test simulated the trigger (Pub/Sub emulator, HTTP POST with synthetic payload, direct controller call). Reasoning for the choice.
- **Idempotency evidence**: test name + assertion; "duplicate delivery → exactly one side effect"
- **Retry evidence**: test name + assertion; transient failure → success on retry
- **Concurrency evidence**: either a test result or an explicit "this change is thread-safe because…" statement

## Output format (handoff)

```
STATUS: PASS | NEEDS REVIEW | BLOCKED
SUMMARY: <3 sentences>

DIFF:
- src/path/to/file.ts — <one-line summary>
- ...

GATES:
- prisma:generate — exit 0
- lint — exit 0, 0 warnings
- type-check — exit 0
- test — exit 0, <N> tests, <M> new
- test:e2e — exit 0 (or "n/a — no e2e applicable")
- build — exit 0

WORKER ASSERTIONS:
- Trigger: <how simulated>
- Idempotency: <test name> — <result>
- Retry: <test name> — <result>
- Concurrency: <test or reasoning>

EVIDENCE:
<tool output excerpts>

NEW TESTS:
- src/...spec.ts — <behavior>

OPEN QUESTIONS:
- <or "none">

PROPOSED COMMIT:
<conventional commit message>
```

## Common failure modes

| Failure | Symptom | Mitigation in brief |
|---|---|---|
| Non-idempotent consumer + redelivery | Duplicate side effects in production | Brief mandates idempotency proof; test asserts dedupe |
| Unhandled transient error swallowed | Message acked despite failed work | Test asserts non-ack on failure path |
| Shared mutable state across threads | Race condition under load | Brief asks for thread-safety reasoning; test or static analysis required |
| Long-running handler blocks event loop | Cloud Run health check fails, instance recycled | Test asserts handler completes within budget; long work is offloaded or chunked |
| Missing Pub/Sub emulator host in tests | Test connects to real Pub/Sub, hangs | Brief specifies `PUBSUB_EMULATOR_HOST` or mocks the client |
| Prisma connection exhaustion under concurrency | Connection-pool errors at high `WORKER_CONCURRENCY` | Test pins concurrency; brief notes pool size assumptions |

## Subagent does not

- Change pub/sub topic/subscription names or Cloud Tasks queue config (Terraform-owned)
- Change `WORKER_CONCURRENCY` defaults without authorization
- Modify files in `packages/` or other `apps/*` workspaces unless **explicitly listed** in the brief's "Cross-package touchpoints" section
- Add a new external dependency without authorization
- Push, PR, or merge

## Lessons embedded

- The workspace declares itself as a "Cloud Run worker service" in `package.json`. It bootstraps a NestJS HTTP server because Pub/Sub push and Cloud Tasks dispatch via HTTP — not because it serves user-facing traffic.
- `worker-thread.ts` is excluded from coverage. Coverage numbers can be misleading; design tests for threaded paths explicitly.
- Sentry + OpenTelemetry are wired in. Tests should not initialize a real Sentry client; mock or set test-mode.
- Prisma 6 is shared with `aqm-api`; schema changes ripple to both. Schema work is escalated to Team.
