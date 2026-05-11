# vcon-ingestion Orchestrator Subagent Brief

> Dispatch contract for the five Python services under `vcon-ingestion/orchestrator/`. Covers four Flask-on-Cloud-Run REST services and one Pub/Sub subscriber daemon.

The orchestrator layer is multi-tenant: organisation and team identity propagate through API-Gateway-injected request headers (`x-org-id`, `x-team-id`, etc.). All services share a Cloud SQL (PostgreSQL) database whose schema lives in `orchestrator/schema/*.sql` and a Memorystore Redis instance for batch state and SSE pub/sub. The five services are independent deployables — each has its own `Dockerfile`, `requirements.txt`, `env.yaml.template`, and (for HTTP services) `openapi.yaml`.

## Which service?

| Service | Shape | Endpoints / role | Quirks |
|---|---|---|---|
| `auth-service/` | Flask + Cloud Run | Login, refresh, logout, password reset, JWKS for API Gateway | Issues JWTs; JWKS public key serves API Gateway verification. PII-sensitive |
| `batch-service/` | Flask + Cloud Run | Submit batch, get batch status; quota pre-check + Redis init + Cloud SQL insert | Owns `agent_routes.py` (BRD-S1-ANON-001 admin routes); registers blueprint |
| `batch-monitor/` | **Cloud Function (2nd gen)** Pub/Sub daemon | Subscribes to per-file completion events; updates Redis counters atomically | NOT Flask — uses `functions-framework`. Background-style worker, not a request handler |
| `reporting-service/` | Flask + Cloud Run | SSE stream of batch progress (via Redis Pub/Sub); paginated batch and usage reports | Long-lived SSE connections; threading concerns |
| `usage-service/` | Flask + Cloud Run | Record file-processing events, increment counters, enforce monthly quotas | Owns cost-tracking writes to Cloud SQL |

If a change spans two services, Team splits the dispatch. `batch-monitor` is the odd one — it lives under `orchestrator/` for ownership but runs as a Cloud Function, not Cloud Run.

## Scope & boundaries

**Owns**:
- Service-local Python modules (`main.py`, helpers, `db_cloudsql.py`, `cost_tracker_pg.py`, `jwt_utils.py`, `password_utils.py`, `email_utils.py`, etc.)
- Service-local tests (when they exist; baseline is sparse — see baseline rule below)
- Per-service `requirements.txt` (bumps require explicit brief authorization)
- `openapi.yaml` per HTTP service — changes to this MUST stay in sync with the actual handler routes (the OpenAPI spec is consumed by API Gateway)
- `agent_routes.py` and other service-local blueprints

**Does not own**:
- Cloud SQL schema (`orchestrator/schema/*.sql`) — schema changes ripple across services and require Team review
- Cloud Run service config (CPU, memory, min-instances, concurrency) — Terraform-owned
- API Gateway routes and header injection (`x-org-id`, `x-team-id`) — out of scope
- Redis topology, namespaces, eviction policy — Terraform / infra config
- The Pub/Sub topic that `batch-monitor` subscribes to — Terraform-owned
- The Cloud Function pipeline (`rawdata-to-transcript`, `transcript-to-vcon`, `vcon-to-vstore`) — owned by `vcon-cloud-function-brief.md`
- The vcon-store API contract — separate repo, separate brief
- Secret Manager bindings, IAM, service-account permissions

## Input fields (Team's brief must include)

1. **Goal** — what changes, why, what observable state proves done (e.g. "POSTing to `/batches` with `csv_file_count > quota_remaining` returns 429 and does not write to Cloud SQL")
2. **Service** — exactly one: `auth-service`, `batch-service`, `batch-monitor`, `reporting-service`, `usage-service`
3. **Endpoint(s) or trigger** — for HTTP services, the route(s) (path + method) and a sample request body. For `batch-monitor`, the Pub/Sub message shape and sample payload
4. **Multi-tenant inputs** — which API-Gateway-injected headers are required (`x-org-id`, `x-team-id`, `x-user-id`, etc.) and what happens when they're missing or malformed
5. **Touchpoints** — expected files within the service's directory
6. **Cross-service / cross-repo touchpoints** — explicit list of files outside this service's directory that the work authorizes the implementer to write. Default is none. Includes:
   - `orchestrator/schema/*.sql` — DDL changes are Team's call; brief escalates rather than authorizing
   - `openapi.yaml` of the same service — if endpoints change, the spec must change with it (in-service edit, not cross-service)
   - Another orchestrator service that consumes a shared Redis key, Cloud SQL row, or Pub/Sub message produced by this one — brief lists the consumer's file and authorizes the edit
   - Pub/Sub message schema consumed from the Cloud Function pipeline (`batch-monitor` only) — if the producer changes shape, a paired `vcon-cloud-function-brief.md` dispatch is required
7. **Acceptance criteria** — bulleted, expressible as endpoint/integration assertions
8. **Idempotency requirement** — explicitly required for `batch-monitor` (Pub/Sub at-least-once delivery); HTTP POSTs may need idempotency keys if the brief says so
9. **Transactionality** — when the work spans Cloud SQL + Redis, the brief specifies which is the source of truth and what compensating action handles partial failure
10. **Quota / cost-event coupling** — if the change touches `usage-service` or any path that records a billable event, the brief states which counters increment and when
11. **Constraints** — what NOT to change (e.g. "do not change JWT signing key handling", "do not modify the Cloud SQL connection-pool init", "do not edit `openapi.yaml` unless this brief explicitly authorizes it")
12. **Test plan** — unit tests at minimum; integration tests when the workspace supports them. Brief specifies whether Cloud SQL is mocked, uses `pytest-redis`, or runs against a local Postgres
13. **Out of scope** — Terraform, IAM, API Gateway routes, schema DDL

## Mandatory verification gates

Each service is its own Python project with its own `requirements.txt`. The repo does not ship a top-level venv; the brief specifies the venv strategy (existing venv, fresh venv via `python -m venv`). The implementer reports the choice in EVIDENCE.

```bash
cd /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/vcon/vcon-ingestion/orchestrator/<service>

# 1. Environment (brief-authorized only)
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 2. Format check (Black)
black --check .

# 3. Tests
python -m pytest -v

# 4. OpenAPI sanity (HTTP services only; not for batch-monitor)
#    The implementer confirms route surface matches openapi.yaml by inspection — no automated linter today
```

**Baseline rule — no tests today**: most orchestrator services lack `test_*.py` files in the source tree. If the brief introduces behavior, the implementer MUST add at least one test covering the new code path. "Service had no tests, so I added none" is a contract violation.

**Service-specific assertions**:

- **Auth shape (`auth-service`)**: any change to token issuance, password handling, or JWKS exposure REQUIRES tests that assert (a) the public flow still works on a valid input, (b) malformed/expired inputs return the documented error code, and (c) password / token never appears in log output (use `common/pii_redaction.py` or local equivalent).
- **Quota correctness (`usage-service`, `batch-service`)**: any change to counter increment or quota check REQUIRES a test that asserts (a) under-quota request succeeds and increments by the expected amount, (b) at-or-over-quota request returns 429 and does NOT increment. Counters MUST be incremented atomically (Redis `INCR` or Cloud SQL `UPDATE ... RETURNING`); the test asserts no double-increment on retry.
- **SSE liveness (`reporting-service`)**: any change to `GET /batches/<id>/files/stream` REQUIRES a test that asserts the response is `text/event-stream` and at least one `data:` frame is emitted before close.
- **Pub/Sub idempotency (`batch-monitor`)**: at-least-once delivery means duplicate messages can arrive. Tests MUST assert that processing the same message twice updates Redis exactly once (idempotency key on the Pub/Sub `messageId` or the event payload's `file_id`).
- **OpenAPI sync (HTTP services only)**: when handler routes or request/response shapes change, the implementer MUST update `openapi.yaml` in the same diff. Failing to do so is a contract violation — API Gateway routes from this spec.

**Pre-flight gotchas**:
- `batch-monitor` is **NOT Flask** — it's a Cloud Function-style Pub/Sub daemon using `functions-framework`. The test pattern matches the `vcon-cloud-function-brief.md` for `batch-monitor` only.
- All Flask services use **gunicorn** in production (`gunicorn` is in `requirements.txt`); tests should hit Flask routes directly via `app.test_client()`, NOT via gunicorn.
- The Cloud SQL connection is established via `google.cloud.sql.connector.Connector` (or `db_cloudsql.py` wrapper). Tests must mock this or use `pytest-redis`-style fixtures — never connect to live Cloud SQL.
- API-Gateway-injected headers are **trusted** by handlers (the gateway is the authentication boundary). Local tests must explicitly set these headers; missing them silently returns 401 or worse.
- `psycopg2-binary` and `pg8000` are both in some `requirements.txt` files — different services chose different drivers. Do NOT unify driver choice across services without explicit authorization.
- `auth-service` exposes JWKS at `/.well-known/jwks.json` — this is read by API Gateway. Do NOT rename this path under any circumstance.
- `reporting-service` SSE uses a background thread reading from Redis Pub/Sub. If the change touches that thread, document thread-safety reasoning in the report.

## Evidence shape (subagent returns)

1. **Status line** — `PASS` | `NEEDS REVIEW` | `BLOCKED`
2. **Summary** — three sentences
3. **Service** — one of the five
4. **Endpoint(s) or trigger** — restate from brief, confirm match in handler/blueprint code
5. **Diff** — file paths with one-line summary per file
6. **Venv strategy** — how the Python environment was established
7. **Gate evidence**:
   - `black --check .` — exit code
   - `pytest` — exit code, test count, new test count
   - OpenAPI sync confirmation (for HTTP services) — manual statement
8. **Service-specific assertion evidence** — per the assertion list above
9. **Schema sanity** — confirm no `orchestrator/schema/*.sql` changes (or BLOCKED with escalation reason)
10. **New tests added** — list with covered behavior
11. **Open questions**
12. **Proposed commit message**

## Output format (handoff)

```
STATUS: PASS | NEEDS REVIEW | BLOCKED
SUMMARY: <3 sentences>
SERVICE: auth-service | batch-service | batch-monitor | reporting-service | usage-service
ENDPOINT(S) / TRIGGER: <e.g. POST /batches, or Pub/Sub topic name>

DIFF:
- orchestrator/<service>/main.py — <one-line summary>
- ...

VENV: <fresh / reused / brief-authorized pip install>

GATES:
- black --check — exit 0
- pytest — exit 0, <N> tests, <M> new
- OpenAPI sync (HTTP only): updated / unchanged / n/a

SERVICE ASSERTIONS:
- Auth shape: <test name> — <result, or "n/a — service is not auth">
- Quota correctness: <test name> — <result, or "n/a">
- SSE liveness: <test name> — <result, or "n/a">
- Pub/Sub idempotency: <test name> — <result, or "n/a — service is not batch-monitor">

SCHEMA: <unchanged / changes requested — BLOCKED for Team review>

EVIDENCE:
<tool output excerpts>

NEW TESTS:
- orchestrator/<service>/test_<name>.py — <behavior>

OPEN QUESTIONS:
- <or "none">

PROPOSED COMMIT:
<conventional commit message>
```

## Common failure modes

| Failure | Symptom | Mitigation in brief |
|---|---|---|
| Counter double-increment under retry | Quota exhausted faster than billable usage; user 429s prematurely | Brief mandates atomicity test; implementer uses `INCR`-style atomics |
| Auth flow change skips PII redaction in logs | Password or token leaks into Cloud Logging | Brief mandates PII test; reuse `common/pii_redaction.py` |
| `openapi.yaml` drifts from handler | API Gateway returns 404 or wrong validation error for a real route | Brief mandates OpenAPI sync as part of the same diff |
| SSE thread crashes silently | Client connection hangs; no progress updates | Brief mandates SSE liveness test; implementer surfaces thread-safety reasoning |
| Duplicate Pub/Sub delivery double-counts files | Batch reported "complete" early or counters drift | Brief mandates idempotency test on `batch-monitor` |
| Tests connect to real Cloud SQL | Test pollutes prod, flaky on CI | Brief specifies mock or `pytest-redis`-style fixture; subagent confirms |
| Schema change snuck into the diff | DDL change ripples across services unreviewed | Subagent BLOCKED on `orchestrator/schema/*` edits unless brief escalates to Team |
| Driver mismatch (psycopg2 vs pg8000) | Inconsistent behavior across services | Subagent does NOT unify drivers without authorization |

## Subagent does not

- Modify `orchestrator/schema/*.sql` — Team's call
- Modify Cloud Run service config (Terraform-owned)
- Modify Pub/Sub topic names, Redis namespaces, IAM
- Rename `auth-service`'s `/.well-known/jwks.json` route under any circumstance
- Rename `functions-framework` registration in `batch-monitor` (deploy target)
- Add or rotate secrets in Secret Manager
- Modify files outside the named service's directory unless **explicitly listed** in the brief's cross-service touchpoints
- Run `pip install` to silently fix import errors — return BLOCKED with the venv state
- Push, commit, or open PRs — Team owns the publish step

## Lessons embedded

- The orchestrator is **multi-tenant**: org and team identity come from API-Gateway-injected headers, NOT from JWT decoding inside the service. Tests must explicitly set the headers.
- **`batch-monitor` is the odd one** — Cloud Function-style Pub/Sub daemon, not Flask. It lives under `orchestrator/` because of ownership, not deploy shape.
- **`openapi.yaml` is the API Gateway contract** for each HTTP service — drift causes 404s or schema-validation rejections on real routes.
- Cloud SQL connection driver (`psycopg2-binary` vs `pg8000`) varies by service — by design or by accident, but do NOT unify without authorization.
- The repo currently has **near-zero tests** in the orchestrator tree. Establishing baseline coverage when the brief authorizes it is in-scope work.
- `auth-service` JWKS endpoint is read by **API Gateway**; the path is load-bearing and must never change.
