# vcon-ingestion Cloud Function Subagent Brief

> Dispatch contract for GCP-native Cloud Functions (2nd gen) under `vcon-ingestion/`. Covers the three pipeline stages: `rawdata-to-transcript`, `transcript-to-vcon`, `vcon-to-vstore`.

These are **GCP Cloud Functions 2nd gen**, deployed via `gcloud functions deploy` (or Terraform), not Firebase Functions. Each stage is its own deployable unit with its own `main.py`, `requirements.txt`, and `env.yaml.template`. Triggers are GCS object-finalization CloudEvents; each stage publishes per-file completion events to Pub/Sub for batch tracking. Distinct from the `firebase/functions/*` workspace in `fuelix/core` — different SDK (`functions_framework`), different deploy mechanism, different test pattern.

## Scope & boundaries

**Owns**:
- Function handlers and entry-point modules per stage (`main.py`, `processor.py`, `vcon.py`, `api_client.py`, etc.)
- Helpers per stage (`gcs_utils.py`, `logging_utils.py`, `db_client.py`, `config.py`, `org_config.py`, `reporting.py`)
- The shared `common/pii_redaction.py` module — but only when the brief explicitly authorizes it (PII redaction logic is consumed by all three stages and is a cross-stage contract)
- Per-stage tests (when they exist; today many stages ship without tests — the brief must mandate adding the missing baseline)
- `requirements.txt` per stage (version bumps require explicit authorization)

**Does not own**:
- GCS bucket names and Eventarc trigger bindings — those live in Terraform / deploy scripts
- Pub/Sub topic names and subscription topology — Terraform-owned
- IAM, Secret Manager bindings, service-account permissions — out of scope
- Cloud SQL schema (`orchestrator/schema/*.sql`) — owned by the orchestrator brief
- The vcon-store API contract (`vcon-to-vstore` POSTs into vcon-store) — cross-repo contract; changes there require a paired dispatch
- `functions-framework` version bumps — runtime contract change, requires Team review

## Which stage?

| Stage | Trigger | Output | Why dispatch here |
|---|---|---|---|
| `rawdata-to-transcript/` | GCS finalization on `CSV_INPUT_BUCKET` (Trigger A) **or** `RAW_TRANSCRIPT_INPUT_BUCKET` (Trigger B) | Normalized `.txt` to `TRANSCRIPTS_OUTPUT_BUCKET`; failed rows to per-batch DLQ CSV | Two function instances share this codebase: `process_csv_trigger` and `process_raw_transcript_trigger`. Renaming either is a deploy-target change |
| `transcript-to-vcon/` | GCS finalization on `TRANSCRIPTS_OUTPUT_BUCKET` | vCon JSON to `VCON_OUTPUT_BUCKET`; archive or DLQ on terminal failure | Single function `process_transcript`. Module-level Pub/Sub publisher singleton — cold-start optimization that is load-bearing |
| `vcon-to-vstore/` | GCS finalization on `VCON_OUTPUT_BUCKET` | POST vCon to vcon-store REST API with GET verification; archive on success, DLQ on failure | Single function `process_vcon_file`. Uses `pybreaker` circuit-breaker; per-org vStore credential lookup via Cloud SQL |

If a change crosses two stages (rare — they communicate only via GCS objects), Team splits the dispatch.

## Input fields (Team's brief must include)

1. **Goal** — what changes, why, what observable state proves done (e.g. "after a CSV upload to `vcon-np-csv-input`, all valid rows produce normalized `.txt` files in `vcon-np-transcripts-output` and the source CSV is archived")
2. **Stage** — exactly one: `rawdata-to-transcript`, `transcript-to-vcon`, or `vcon-to-vstore`
3. **Trigger** — GCS bucket name, event type (`google.cloud.storage.object.v1.finalized`), and a sample GCS object metadata payload
4. **Function entry-point name** — the exact `functions_framework` registration; do not rename without explicit authorization (deploy targets break)
5. **Touchpoints** — expected files within the stage's directory
6. **Cross-stage / cross-repo touchpoints** — explicit list of files outside this stage's directory that the work authorizes the implementer to write. Default is none. Includes:
   - `common/pii_redaction.py` if the work changes PII shape or coverage — flag because the other two stages also consume it
   - The downstream stage's expected input format (vCon JSON shape, normalized `.txt` header schema) — when the producer changes the shape, the consumer's parser must change too. The brief must call this out and authorize the corresponding edit in the consumer stage
   - The vcon-store API request/response shape (only relevant for `vcon-to-vstore`) — if the request body or expected response changes, a paired `vcon-store-brief.md` dispatch is required and the brief must say so
   - Pub/Sub batch-status message schema (consumed by `orchestrator/batch-monitor`) — schema changes require a paired orchestrator dispatch
7. **Acceptance criteria** — bulleted, each expressible as a unit test or integration assertion
8. **Idempotency requirement** — GCS finalization can fire multiple times for the same object under network glitches; the brief must specify whether duplicate processing must be safe and how (file-level dedupe key, output-existence check, etc.)
9. **DLQ behavior** — what classifies as terminal failure vs transient; where the artifact goes on terminal failure (DLQ bucket name from `env.yaml.template`)
10. **Pub/Sub publish contract** — when the stage publishes a batch-status event, the brief specifies the message shape (the orchestrator's `batch-monitor` consumes these)
11. **Cold-start budget** — these functions run on Cloud Functions 2nd gen with auto-scaling; module-level singletons (Pub/Sub publisher, Storage client) matter. Brief flags if cold-start headroom is constrained for this stage
12. **Constraints** — what NOT to change (e.g. "do not rename `process_vcon_file`", "do not edit `functions-framework` version", "do not introduce a new external dependency")
13. **Test plan** — unit tests at minimum; integration tests if the stage already has them. Brief specifies whether GCS / Pub/Sub are mocked or use emulators
14. **Out of scope** — Terraform, IAM, schedule strings, bucket creation

## Mandatory verification gates

Each stage is its own Python project with its own `requirements.txt`. The vcon-ingestion repo does **not** ship a top-level venv; the brief specifies how the implementer should establish a working Python environment for the stage (existing venv, fresh venv, or `python -m venv`). The implementer reports the choice in EVIDENCE.

```bash
cd /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/vcon/vcon-ingestion/<stage>

# 1. Environment (the brief specifies venv strategy; pip install is BLOCKED unless the brief authorizes it)
python -m venv .venv && source .venv/bin/activate    # only if brief authorizes
pip install -r requirements.txt                       # only if brief authorizes

# 2. Format check (Black; vcon-ingestion does not pin a line-length; default 88 unless local config says otherwise)
black --check .

# 3. Tests (per stage; many stages currently ship without tests — see baseline rule below)
python -m pytest -v
```

**Baseline rule — no tests today**: the three stages currently lack `test_*.py` / `tests/` directories. If the brief introduces behavior, the implementer MUST add at least one unit test that exercises the new code path. "Stage had no tests, so I added none" is a contract violation. The implementer reports the new test file path in NEW TESTS.

**Stage-specific assertions**:

- **Idempotency proof** (any stage): if the brief declared duplicate processing must be safe, add a test that invokes the handler twice with the same GCS event payload and asserts side-effects happened exactly once (e.g. single output object, single Pub/Sub publish, single archive move).
- **DLQ proof** (any stage that classifies failure as terminal): add a test that forces a terminal failure and asserts the artifact moved to the DLQ bucket and that no downstream Pub/Sub message was published.
- **Circuit-breaker proof** (`vcon-to-vstore` only): if the change touches `api_client.py` or `pybreaker` config, add a test that exercises the breaker's open / half-open transitions.
- **PII redaction proof** (any stage that changes `common/pii_redaction.py` or its callers): add a test that asserts the new shape redacts the expected fields and does not regress existing coverage.

**Pre-flight gotchas**:
- These are **GCP Cloud Functions 2nd gen**, not Firebase Functions. Do not import from `firebase_functions`. The entry-point decorator is `@functions_framework.cloud_event` (or `@functions_framework.http` for HTTP-triggered).
- `transcript-to-vcon` and `vcon-to-vstore` initialize a module-level Pub/Sub publisher singleton at first use. Tests that import the module multiple times must reset the singleton or expect the first instance to leak across tests.
- The three stages have **separate `requirements.txt` files**; do not assume version parity across stages (e.g. `functions-framework` may be pinned slightly differently).
- `vcon-to-vstore` performs **per-org vStore credential lookup** via Cloud SQL (`db_client.py`, `org_config.py`); tests must mock the lookup or use a test fixture, never hit live Cloud SQL.
- Trigger A and Trigger B in `rawdata-to-transcript` are separate deployment instances sharing one codebase — both function names appear in the registered entry points. Do not collapse them.
- GCS event payloads are CloudEvents structurally; the function receives a `cloud_event` object with `data` containing the object metadata. Mock fixtures should match the CloudEvent envelope.

## Evidence shape (subagent returns)

1. **Status line** — `PASS` | `NEEDS REVIEW` | `BLOCKED`
2. **Summary** — three sentences
3. **Stage** — one of the three
4. **Function entry-point name(s)** — confirm match against `main.py` registration
5. **Diff** — file paths with one-line summary per file
6. **Venv strategy** — fresh venv, existing venv reused, system pip (only if brief authorized) — name the choice
7. **Gate evidence**:
   - `black --check .` — exit code
   - `pytest` — exit code, test count, new test count
8. **Idempotency / DLQ / circuit-breaker / PII evidence** — per the stage's assertion list
9. **Pub/Sub publish contract** — confirm the message shape your code produces matches the brief
10. **New tests added** — list with covered behavior
11. **Open questions**
12. **Proposed commit message**

## Output format (handoff)

```
STATUS: PASS | NEEDS REVIEW | BLOCKED
SUMMARY: <3 sentences>
STAGE: rawdata-to-transcript | transcript-to-vcon | vcon-to-vstore
FUNCTION(S): <entry-point name(s)>

DIFF:
- rawdata-to-transcript/processor.py — <one-line summary>
- ...

VENV: <fresh / reused existing / brief-authorized pip install>

GATES:
- black --check — exit 0
- pytest — exit 0, <N> tests, <M> new

STAGE ASSERTIONS:
- Idempotency: <test name> — <result, or "n/a per brief">
- DLQ: <test name> — <result, or "n/a per brief">
- Circuit breaker: <test name or "n/a — not vcon-to-vstore or no breaker touch">
- PII redaction: <test name or "n/a — common/pii_redaction.py not touched">

PUBSUB CONTRACT:
- <message schema produced; confirm match against brief>

EVIDENCE:
<tool output excerpts>

NEW TESTS:
- <stage>/test_<name>.py — <behavior>

OPEN QUESTIONS:
- <or "none">

PROPOSED COMMIT:
<conventional commit message>
```

## Common failure modes

| Failure | Symptom | Mitigation in brief |
|---|---|---|
| Renamed function entry-point breaks deploy | Eventarc fires but invokes a missing target | Brief specifies "do not rename `<function-name>`"; subagent confirms registration unchanged |
| Mocked GCS in tests but real GCS in handler | Test passes locally, runtime fails on first event | Brief mandates a unit test exercising the actual cloud_event-decorated function |
| Module-level publisher singleton leaks across tests | Flaky test order, "publisher already initialized" | Tests reset the module-level singleton or use a fresh import per test |
| Duplicate GCS event → duplicate POST to vcon-store | vcon-store receives the same vCon twice | Brief mandates idempotency proof; test asserts dedupe |
| Cold-start regression from new top-level imports | Latency spike at first request | Brief flags cold-start budget; subagent avoids new module-level imports |
| Stage 3 POST shape drift breaks vcon-store | 422 from vcon-store after deploy | Brief flags the cross-repo contract; paired `vcon-store-brief.md` dispatch if request shape changes |
| `requirements.txt` drift across stages | Inconsistent `google-cloud-storage` versions, surprising behavior at the boundary | Subagent does NOT unify versions without authorization; flags drift in OPEN QUESTIONS |
| Per-org credential lookup hits live Cloud SQL in tests | Test pollutes production data or fails on missing creds | Brief mandates the lookup is mocked or fixture-backed |

## Subagent does not

- Rename `functions-framework` registrations (deploy targets break)
- Modify GCS bucket names or Eventarc trigger bindings (Terraform-owned)
- Modify Pub/Sub topic names (Terraform-owned)
- Bump the Python runtime version
- Add a new external dependency without explicit brief authorization
- Touch `orchestrator/`, `ingestion-webapp/`, or `vcon-store` files unless the brief explicitly authorizes a paired dispatch
- Run `pip install` to silently fix import errors — return BLOCKED with the venv state
- Push, commit, or open PRs — Team owns the publish step

## Lessons embedded

- `rawdata-to-transcript` deploys as **two function instances** from one codebase (`process_csv_trigger` and `process_raw_transcript_trigger`). Confirm both entry-points are registered when touching either path.
- `transcript-to-vcon` and `vcon-to-vstore` use a **module-level Pub/Sub publisher singleton** with explicit `BatchSettings` to avoid per-invocation gRPC channel creation. Do not break this pattern when adding new publish paths.
- `vcon-to-vstore` is the **only stage with a cross-repo contract**: it POSTs vCons to vcon-store. Changes to the request body, headers, or expected response require a paired `vcon-store-brief.md` dispatch.
- The pipeline emits **per-file batch-status events** to a Pub/Sub topic consumed by `orchestrator/batch-monitor`. Schema changes to those events are an orchestrator-cross-cutting change.
- `common/pii_redaction.py` is consumed by all three stages — it's an internal shared module. Treat it like a cross-package contract within the repo.
- Tests are sparse-to-absent today. Establishing baseline test coverage is acceptable scope when authorized by the brief.
