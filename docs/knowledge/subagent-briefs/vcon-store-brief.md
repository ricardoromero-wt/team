# vcon-store Subagent Brief

> Dispatch contract for `vcon-store/` — the FastAPI service that persists vCons and exposes the REST surface consumed by `vcon-to-vstore` (the Cloud Function ingestion pipeline) and by analytics / replay tooling.

vcon-store is a Poetry-managed Python 3.11–3.12 FastAPI service. Redis is the primary cache and pub/sub; persistent storage is pluggable via storage adapters under `server/storage/` (Postgres via Peewee, MongoDB, Elasticsearch, Milvus, S3, SFTP, file). vCons can be processed by a chain of links under `server/links/` (LLM enrichment, classification, etc.). Background processing runs via `server/follower.py` consuming Pub/Sub. Production deploy is gunicorn + uvicorn.

## Scope & boundaries

**Owns**:
- FastAPI routes and route helpers (`server/api.py`, route modules under `server/`)
- Storage adapters under `server/storage/<adapter>/` — adapters share a base contract in `server/storage/base.py`
- Link processors under `server/links/<link>/` — each is a vCon enrichment step
- Pub/Sub follower (`server/follower.py`) and GCP integration (`server/gcp_pubsub.py`)
- Settings, config loaders, DLQ utilities (`server/settings.py`, `server/config.py`, `server/dlq_utils.py`, `server/redis_mgr.py`, `server/redis_json_compat.py`)
- Tests under `tests/` (real test infrastructure exists — `conftest.py` and `pytest.ini` at the repo root)
- `pyproject.toml` for dependency declaration (bumps require explicit brief authorization; lockfile commits require it too)
- `vcon-store-main/` and `vcon-admin/` subdirectories — treat as separate sub-projects within the repo; the brief specifies which one is in scope

**Does not own**:
- The cross-repo API contract consumed by `vcon-ingestion/vcon-to-vstore` — changes to request/response shapes require a paired `vcon-cloud-function-brief.md` dispatch for the consumer
- Secret Manager bindings, IAM, service-account permissions
- Cloud Run / Compute Engine deploy config (`docker/`, `docker-compose.yml`, `nginx.conf`, deployment manifests live in this repo but the contents are infra — Team review for changes)
- Production tenant config (`prod_mgt/`, `update_tenant_pii_config.py`) — operational, not engineering
- Redis topology and Memorystore config
- The downstream consumers of vcon-store events (analytics dashboards, etc.) — out of scope, but consumer impact must be reported when message shapes change

## Input fields (Team's brief must include)

1. **Goal** — what changes, why, what observable state proves done (e.g. "POST /vcon with a valid v0.0.1 vCon writes to Redis and the configured Postgres adapter; GET /vcon/<uuid> returns the same payload")
2. **Surface** — one of:
   - **API route** — path + method, request/response shape, sample payload
   - **Storage adapter** — which adapter (`redis_storage`, `postgres`, `mongo`, `elasticsearch`, `milvus`, `s3`, `sftp`, `file`, `dataverse`, `chatgpt_files`, `spaceandtime`), and what part of `base.py` is implemented or modified
   - **Link processor** — which link, the vCon-in / vCon-out contract, what enrichment it adds
   - **Pub/Sub follower** — what topic, what message shape, what downstream effect
3. **Touchpoints** — expected files within `server/`
4. **Cross-component / cross-repo touchpoints** — explicit list of files outside the named component that the work authorizes the implementer to write. Default is none. Includes:
   - The adapter `base.py` contract — if the change modifies the shared interface, every adapter must be reviewed for compatibility, and the brief authorizes the per-adapter edits
   - `config.yml` / `example_config.yml` if the change introduces a new configurable surface
   - The cross-repo `vcon-to-vstore` Cloud Function — if the API request/response shape changes, a paired `vcon-cloud-function-brief.md` dispatch is REQUIRED and the brief must say so
5. **Acceptance criteria** — bulleted, each expressible as a pytest assertion
6. **Storage semantics** — if the change touches persistence, the brief specifies:
   - Which adapter is the source of truth for this code path (Redis cache vs. configured persistent store)
   - Redis caching behavior on read-miss (the API auto-stores from persistent store back to Redis with `VCON_REDIS_EXPIRY`); brief flags if this behavior changes
   - DLQ routing on persistence failure (`dlq_utils.py`)
7. **Auth** — vcon-store uses `APIKeyHeader` for API key auth on protected routes; brief specifies whether the new route is protected and which key scope
8. **Idempotency** — `POST /vcon` semantics under duplicate UUID: brief specifies whether to reject, replace, or merge
9. **Constraints** — what NOT to change (e.g. "do not change Redis key format", "do not modify `base.py`", "do not add a new storage backend", "do not bump FastAPI / Starlette versions")
10. **Test plan** — pytest with the existing harness; specify whether real Redis (`pytest-redis`), real Postgres (testcontainers or local), or mocks are used
11. **Out of scope** — secrets, deploy config, tenant operational changes

## Mandatory verification gates

vcon-store is **Poetry-managed**. The implementer uses Poetry's venv, not a hand-rolled one. If Poetry is not available, the implementer returns BLOCKED — do not fall back to system pip.

```bash
cd /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/vcon/vcon-store

# 1. Environment (brief specifies whether to run `poetry install` or use existing .venv)
poetry install                            # only if brief authorizes
poetry shell                              # or: source $(poetry env info --path)/bin/activate

# 2. Format check (Black; pyproject.toml pins line-length = 120, skip-string-normalization = true)
black --check --line-length 120 --skip-string-normalization .

# 3. Tests (pytest; conftest.py and pytest.ini exist at repo root)
poetry run pytest -v
# or, inside the activated env:
pytest -v
```

**Tests exist**: unlike `vcon-ingestion`, vcon-store ships real test infrastructure. The implementer ADDS to it, does not establish baseline coverage from scratch.

**Surface-specific assertions**:

- **Adapter contract proof (storage adapters)**: any change to a storage adapter under `server/storage/<adapter>/` MUST have tests covering at minimum (a) round-trip `save` + `get` for a known vCon, (b) `get` on a missing key returns the documented null / error, (c) any new contract method matches the interface in `base.py`. If `base.py` itself changes, the implementer reports per-adapter compatibility status in evidence.
- **Redis cache behavior (any API change)**: tests assert that read-miss-then-load-from-persistent-store still writes back into Redis with `VCON_REDIS_EXPIRY` honored. Regressions here cause throughput degradation in production.
- **Link processor I/O contract (`server/links/`)**: any new or modified link MUST have a test that asserts `process(vcon_in) → vcon_out` preserves keys the link does not own and produces the expected new keys. Links chain — silent mutation is a contract violation.
- **DLQ behavior (any persistence path)**: when persistence fails, tests assert the artifact lands in the DLQ via `dlq_utils.py` and the originating request does NOT return success.
- **Cross-repo contract preservation (API routes consumed by `vcon-to-vstore`)**: if `POST /vcon`, the auth header shape, or the GET-verify response changes, the implementer flags it explicitly in evidence as a cross-repo break and the brief MUST have authorized a paired dispatch. Silent shape changes ship and break production at the next ingestion run.

**Pre-flight gotchas**:
- **Poetry is the package manager.** Do NOT run bare `pip install`. The `pyproject.toml` declares the dependency tree; `poetry.lock` is the resolved set.
- **Line length is 120**, not Black's default 88. `[tool.black]` in `pyproject.toml` pins this. Tests run with the same setting.
- **`skip-string-normalization = true`** in Black config — don't reformat single-quoted strings to double quotes (or vice versa) absent a reason.
- The FastAPI app uses `APIKeyHeader` security; tests must supply the configured API key.
- `vcon-store-main/` and `vcon-admin/` are **separate sub-projects** in the repo. The main `server/` directory is what most work touches. Brief specifies if work goes into one of the sub-projects.
- `redis_json_compat.py` exists because older Redis versions lack RedisJSON; do NOT remove it without checking what runtime version the deployment uses.
- `transformers` is in the dependency tree (for HuggingFace-backed link processors) — adds significant cold-start cost. Importing it at module top-level affects boot time.
- The follower (`follower.py`) is a long-running consumer; tests should mock the Pub/Sub client rather than connecting to live infrastructure.
- `tests/core/` and `tests/dataset/` are the existing test layout; new tests go where the code under test lives.

## Evidence shape (subagent returns)

1. **Status line** — `PASS` | `NEEDS REVIEW` | `BLOCKED`
2. **Summary** — three sentences
3. **Surface** — API route, storage adapter, link processor, or Pub/Sub follower
4. **Touchpoint(s)** — restate the named files
5. **Diff** — file paths with one-line summary per file
6. **Environment** — `poetry install` performed? Existing venv? Brief-authorized?
7. **Gate evidence**:
   - `black --check --line-length 120 --skip-string-normalization .` — exit code
   - `pytest` — exit code, test count, new test count
8. **Surface-specific assertion evidence** — per the assertion list above
9. **Cross-repo contract status** — if API shape touched, explicit statement of consumer impact and confirmation of paired-dispatch authorization
10. **`base.py` adapter compatibility** — if `base.py` was touched, per-adapter status
11. **New tests added** — list with covered behavior
12. **Open questions**
13. **Proposed commit message**

## Output format (handoff)

```
STATUS: PASS | NEEDS REVIEW | BLOCKED
SUMMARY: <3 sentences>
SURFACE: api-route | storage-adapter | link-processor | pubsub-follower
TOUCHPOINT(S): <e.g. POST /vcon, server/storage/postgres/, server/links/huggingllm/>

DIFF:
- server/api.py — <one-line summary>
- server/storage/postgres/__init__.py — <one-line summary>
- ...

ENVIRONMENT: <poetry install run / existing venv reused>

GATES:
- black --check (line-length=120, skip-string-normalization) — exit 0
- pytest — exit 0, <N> tests, <M> new

SURFACE ASSERTIONS:
- Adapter contract: <test name, per-adapter status, or "n/a — no adapter touched">
- Redis cache behavior: <test name or "n/a — read path unchanged">
- Link processor I/O: <test name or "n/a — no link touched">
- DLQ behavior: <test name or "n/a — no persistence path touched">
- Cross-repo contract: unchanged | changed: <consumer impact, paired dispatch authorized>

EVIDENCE:
<tool output excerpts>

NEW TESTS:
- tests/core/test_<name>.py — <behavior>

OPEN QUESTIONS:
- <or "none">

PROPOSED COMMIT:
<conventional commit message>
```

## Common failure modes

| Failure | Symptom | Mitigation in brief |
|---|---|---|
| Silent API shape change | `vcon-to-vstore` POSTs start 4xx-ing in production | Brief requires explicit cross-repo contract statement; paired dispatch on shape change |
| Adapter interface drift | One adapter implements new method, others don't; runtime AttributeError when config switches backend | Subagent reports per-adapter status when `base.py` touched |
| Redis cache-miss writeback regression | Reads slow; persistent store thrashed | Brief mandates cache-behavior test on any API change |
| Link processor mutates unrelated keys | Downstream link expects keys that previous link removed | Brief mandates I/O contract test |
| DLQ skipped on persistence failure | Failed writes silently dropped | Brief mandates DLQ assertion |
| Poetry install drifts from `poetry.lock` | CI works, local doesn't, or vice versa | Subagent uses `poetry install` exactly; no bare pip |
| Black config ignored (default 88 vs configured 120) | Diff full of reformatting noise | Subagent runs Black with the pinned line-length and string-normalization flag |
| `transformers` imported at module top-level | Cold-start latency spike | Imports moved into function bodies where the model is actually used |
| Follower tests hit live Pub/Sub | Test pollutes prod, flaky on CI | Tests mock the Pub/Sub client |

## Subagent does not

- Bump FastAPI, Starlette, or Pydantic majors (`fastapi`, `starlette`, `pydantic` are core surface; changes ripple)
- Modify `poetry.lock` directly — it's a generated artifact; changes happen via `poetry add/update`
- Add a new storage backend without explicit brief authorization
- Modify `vcon-store-main/` or `vcon-admin/` unless the brief explicitly names one
- Modify infra files (`docker/`, `docker-compose.yml`, `nginx.conf`, `cloud-run.yaml`-equivalent) — Team review
- Modify the cross-repo API contract without a paired `vcon-cloud-function-brief.md` dispatch
- Add or rotate API keys / secrets in Secret Manager
- Run bare `pip install`
- Push, commit, or open PRs — Team owns the publish step

## Lessons embedded

- **Poetry, not pip.** `pyproject.toml` + `poetry.lock` are the source of truth.
- **Black config differs from defaults**: line-length 120, skip-string-normalization. Always pass these flags or use `[tool.black]`.
- **Adapters share a contract in `server/storage/base.py`.** Touching `base.py` ripples to every adapter; treat it like a shared schema.
- **Redis is the cache, not the source of truth** (when a persistent backend is configured). Cache-miss → load → writeback is a hot path; regressions are expensive.
- **Cross-repo contract**: `POST /vcon`, the auth header, and the verification GET are consumed by `vcon-ingestion/vcon-to-vstore`. Silent changes ship and break ingestion at the next batch.
- **`transformers` is heavy** — module-level imports cost cold-start.
- **`vcon-store-main/` and `vcon-admin/` are sub-projects** within the repo, not subdirectories of `server/`. Different ownership boundary; the brief calls out which is in scope.
