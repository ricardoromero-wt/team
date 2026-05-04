# Cloud Function Subagent Brief

> Dispatch contract for Firebase Cloud Functions in `firebase/functions/`. The directory hosts **two** parallel codebases: `firebase/functions/typescript/` and `firebase/functions/python/`. The brief format is the same; the gates differ by language.

This brief also covers **Cloud Scheduler-triggered functions** — those are scheduled Cloud Functions using `onSchedule(...)` (TS) or the equivalent Flask + Cloud Scheduler invocation pattern (Python). Cloud Scheduler is not a separate execution shape; it is one of several trigger types that land in this brief.

## Scope & boundaries

**Owns**:
- Function handlers (HTTP, scheduled, pub/sub, Firestore triggers, storage triggers)
- Helpers and integrations under `src/` (TS) or top-level modules (Python)
- Unit tests (`jest --config jest.unit.config.js` for TS, `pytest` or `unittest` for Python)
- Integration tests (`jest --config jest.integration.config.js` for TS)

**Does not own**:
- Trigger topology — schedule strings, pub/sub topic creation, Firestore index changes — those are Terraform-owned and require Team review
- IAM, Secret Manager bindings, service-account permissions
- Function runtime version (`engines.node` in TS, `runtime` in Python `firebase.json`) — version bumps require Team review
- The Python Flask harness or the TS `firebase-functions` SDK version — out of scope for routine work

## Which codebase?

| Codebase | When to dispatch | Gates differ how |
|---|---|---|
| `firebase/functions/typescript/` | New TS function, edit existing TS function, scheduled (TS `onSchedule`) | Jest unit + integration, ESLint, `tsc` (build only — no separate type-check script) |
| `firebase/functions/python/` | New Python function, edit existing Python function | `black .`, `pytest`, plus any project-specific linters in `requirements.txt` |

If a brief implies cross-language work (rare), Team splits the dispatch.

## Input fields (Team's brief must include)

1. **Goal** — what the function does, why
2. **Codebase** — `firebase/functions/typescript` or `firebase/functions/python`
3. **Trigger type** — HTTP, scheduled, pub/sub, Firestore, storage. Include schedule string or topic name if applicable
4. **Function name** — kebab-case for TS exports, snake_case for Python module functions; must match the deployment manifest
5. **Touchpoints** — files expected to change
6. **Cross-package touchpoints** — explicit list of files outside this Cloud Functions workspace that this work authorizes the implementer to write. Default is none. When the work changes a published message, a consumed message shape, a Firestore document shape, or any cross-service contract, this section must include:
   - Source-of-truth Zod schema in `packages/common-types/src/<domain>/schemas/` if one exists for the affected contract (TS workspace can import directly; Python hand-mirrors and any change must be reflected in BOTH places)
   - Test fixtures in adjacent `apps/*-api`, `apps/*-worker`, `apps/*-web`, or the parallel Cloud Functions workspace that consume the same contract and would fail validation without an update
   The Team dispatching the brief is responsible for identifying these via the researcher's cross-package scan; the implementer does not infer them. If a touchpoint is discovered mid-work that wasn't authorized, the implementer STOPS and surfaces it in OPEN QUESTIONS.
7. **Acceptance criteria** — bulleted, each expressible as a test
8. **Trigger sample** — for HTTP: sample request body. For pub/sub: sample message JSON. For scheduled: schedule expression and what state proves the run happened
9. **Idempotency requirement** — same as worker brief: scheduled and pub/sub functions can be redelivered
10. **Cold-start sensitivity** — flag if the function is on a hot path where init cost matters (rare for scheduled, common for HTTP)
11. **Constraints** — what NOT to change (e.g. "do not modify the schedule expression", "do not change the function export name — it's referenced by deployment config")
12. **Test plan** — unit + integration. Integration tests use the Firebase emulator suite; the brief specifies which emulators must be up
13. **Out of scope**

## Mandatory verification gates

### TypeScript codebase (`firebase/functions/typescript`)

```bash
cd firebase/functions/typescript

# 1. Lint
pnpm run lint

# 2. Build (this is the type-check; there is no separate type-check script)
pnpm run build

# 3. Unit tests
pnpm run test:unit

# 4. Integration tests (Firebase emulator suite required)
pnpm run test:integration
```

### Python codebase (`firebase/functions/python`)

```bash
cd firebase/functions/python
source venv/bin/activate                                # or equivalent virtualenv activation

# 1. Format check
black --check .

# 2. Tests
python -m pytest tests/                                 # or the project's preferred runner
```

**Pre-flight gotchas (TS)**:
- The TS workspace has *no* `type-check` script — `tsc` is run via `build`. A "lint passes but build fails" gate failure means a type error.
- `firebase-functions` v5 changed export shapes from v4. Do not assume v4 docs apply.
- Integration tests require the Firebase emulator suite (`firebase emulators:start`); the test config assumes the emulators are reachable.
- The TS workspace pins Node 22; the rest of the monorepo runs Node 20+. Run from this workspace's lockfile, not the root.

**Pre-flight gotchas (Python)**:
- The Python codebase ships its own `venv/` and `requirements.txt`; do not install into the system Python.
- `mock-creds.json` exists in the workspace — useful for emulator-mode tests; do not check actual creds in.
- `gunicorn.ctl` indicates the function is served via gunicorn locally; tests should hit handlers directly, not via the gunicorn process.

**Scheduler-specific assertions**:
- If the change touches a scheduled function, the subagent must add a unit test that invokes the handler directly and asserts the work is done. The subagent does NOT verify the schedule string is honored at runtime — that's Cloud Scheduler's job and is verified at deploy time.
- If the change *modifies* the schedule string, that's out of scope for this brief — escalate to Team because deploy/Terraform are involved.

## Evidence shape (subagent returns)

1. **Status line** — `PASS` | `NEEDS REVIEW` | `BLOCKED`
2. **Summary** — three sentences
3. **Diff** — file paths with one-line summary per file
4. **Codebase** — `typescript` or `python`
5. **Trigger type** — restate from brief, confirm match in code
6. **Function export/name** — confirm matches what's deployed
7. **Gate evidence**:
   - TS: lint, build, test:unit, test:integration with exit codes
   - Python: black, pytest with exit codes
8. **Idempotency evidence** — for scheduled / pub/sub triggers, test name + assertion
9. **Emulator usage** — which emulators were started for integration tests; output excerpt confirming connection
10. **New tests added** — list with covered behavior
11. **Open questions**
12. **Proposed commit message**

## Output format (handoff)

```
STATUS: PASS | NEEDS REVIEW | BLOCKED
SUMMARY: <3 sentences>
CODEBASE: typescript | python
TRIGGER: http | scheduled | pubsub | firestore | storage
FUNCTION: <export name>

DIFF:
- src/path/to/file.ts — <one-line summary>
- ...

GATES (TS):
- lint — exit 0, 0 warnings
- build (type-check via tsc) — exit 0
- test:unit — exit 0, <N> tests, <M> new
- test:integration — exit 0, <K> tests

GATES (Python):
- black --check — exit 0
- pytest — exit 0, <N> tests, <M> new

SCHEDULER ASSERTIONS:
- <only if scheduled> Idempotency test: <name> — <result>

EMULATORS:
- <e.g. firestore, pubsub, auth — versions/ports>

EVIDENCE:
<tool output excerpts>

NEW TESTS:
- <path> — <behavior>

OPEN QUESTIONS:
- <or "none">

PROPOSED COMMIT:
<conventional commit message>
```

## Common failure modes

| Failure | Symptom | Mitigation in brief |
|---|---|---|
| Renamed function export breaks deploy | Deploy succeeds, scheduler invokes nonexistent target | Brief specifies "do not rename function export"; subagent confirms export name unchanged |
| Schedule string drift | Function runs at wrong cadence | Schedule changes are out of scope for this brief — escalate to Team |
| Integration test against real GCP | Test hits production resources, slow or destructive | Brief mandates emulator usage; subagent confirms emulator hosts in evidence |
| `firebase-functions` v5 vs v4 imports | Subtle export differences cause runtime failures only | Subagent confirms version, uses v5-shape imports |
| Python venv mismatch | `pip install` from wrong env, tests fail with missing deps | Brief specifies `source venv/bin/activate` before any tool run |
| Cold-start regression on hot HTTP function | Latency spike post-deploy | Brief flags cold-start sensitivity; subagent avoids new top-level imports |

## Subagent does not

- Modify schedule strings, pub/sub topic names, or Firestore index files — those are Terraform/deploy-config territory
- Modify `engines.node` (TS) or runtime (Python) — version bumps require Team review
- Modify files outside this workspace unless **explicitly listed** in the brief's "Cross-package touchpoints" section
- Add or rotate secrets in Secret Manager
- Push, deploy, or invoke `firebase deploy`
- Change cross-language code — TS function calling Python helper or vice versa is out of scope

## Lessons embedded

- TS workspace has its own pnpm lockfile (`firebase/functions/typescript/pnpm-lock.yaml`) separate from the monorepo root. Run installs from this directory.
- `firebase-functions` is at v5; `firebase-admin` is at v12 in this workspace (the rest of the monorepo uses v13 in apps). Do not unify without intent.
- The TS workspace lists Node 22 in `engines`; pin local Node version when troubleshooting.
- Python codebase has subdirectories per domain (`copilots/`, `encrypt/`, `generation/`, `migration/`, `model_validation/`, `rag/`). Cross-domain changes are rare; brief should specify a single domain when possible.
