# vcon-ingestion Webapp Subagent Brief

> Dispatch contract for `vcon-ingestion/ingestion-webapp/` — the file-upload UI that lets operators submit CSVs and raw transcripts to the ingestion pipeline.

The webapp is a two-tier deployment with both tiers in one workspace:
- **Backend**: Node.js + Express (`backend/server.js`). Mounts `/auth` and signed-URL endpoints. Issues GCS signed URLs so the browser uploads directly to GCS buckets (no streaming through the backend).
- **Frontend**: React 19 + Create React App (`frontend/`) + Tailwind CSS. Talks to the backend over `axios`.

Both tiers ship from a single Cloud Run service (`cloud-run.yaml`, `Dockerfile`). The frontend is built and served by the backend in production; in development they run separately.

## Scope & boundaries

**Owns**:
- Backend Express routes (`backend/routes/*.js`), middleware (`backend/middleware/*.js`), config (`backend/config/*.js`)
- Backend root manifest (`ingestion-webapp/package.json` — note: backend has no separate `package.json`, it shares the root one)
- Frontend React app under `frontend/src/`, frontend `package.json`, Tailwind config, PostCSS config
- Frontend tests (CRA / react-scripts Jest harness)
- Backend tests — currently absent; baseline must be established by any work that introduces behavior

**Does not own**:
- GCS bucket names and CORS policy (`setup-cors.sh`, `update-bucket-cors.sh`, `FIX_BUCKET_CORS.md`) — Terraform / one-shot setup scripts. Brief escalates if the change requires CORS edits.
- Cloud Run service config (`cloud-run.yaml`, `deploy-cloud-run.sh`) — Terraform-owned
- Authentication identity provider config — the webapp authenticates against orchestrator's `auth-service`; changes there are out of scope for this brief and require a paired `vcon-orchestrator-brief.md` dispatch
- API Gateway routing — out of scope
- The orchestrator backend (`/batches`, `/reports/*`) — separate brief
- Frontend UX design decisions — the brief inherits "sanity gates, not design ownership" from Team's frontend posture. Implementer fixes broken builds, console errors, broken nav. Does not redesign components.

## Input fields (Team's brief must include)

1. **Goal** — what changes, why, what observable behavior proves done (e.g. "submitting a CSV batch from the dashboard returns the batch ID and renders it in the recent-batches list within 2 seconds")
2. **Tier** — `backend`, `frontend`, or `both`. If `both`, the brief must enumerate touchpoints in each tier
3. **Endpoint or component** — for backend: route path + method, sample request body, expected response. For frontend: component path, prop contract, expected DOM/behavior change
4. **Touchpoints** — expected files within `backend/` or `frontend/src/`
5. **Cross-tier / cross-service touchpoints** — explicit list of files outside the named tier that the work authorizes the implementer to write. Default is none. Includes:
   - The other tier of this workspace (most common cross-tier case is "new backend endpoint + new frontend consumer")
   - The orchestrator's `openapi.yaml` for any orchestrator service the frontend consumes — confirms the contract the frontend assumes; mismatches require a paired orchestrator dispatch
   - GCS bucket configuration — escalate, do not edit
6. **Auth requirement** — the webapp authenticates against orchestrator's `auth-service` (JWT in `Authorization` header). Brief specifies whether the new path requires auth, what role/claim is checked, and what the unauthenticated response is
7. **CORS / origin** — backend hard-codes allowed origins and `*.run.app` for Cloud Run; brief flags if a change adds a new origin or alters the matcher
8. **Acceptance criteria** — bulleted, each expressible as a test (backend: supertest; frontend: react-testing-library)
9. **Constraints** — what NOT to change (e.g. "do not change the `cors` allowlist", "do not introduce a new top-level frontend route without authorization")
10. **Test plan** — backend tests use whichever harness is added; frontend tests use CRA's Jest. Brief specifies the assertion shape
11. **Out of scope** — Terraform, Cloud Run config, CORS bucket setup, design changes

## Mandatory verification gates

The webapp uses **two separate `package.json` manifests**:
- Root `ingestion-webapp/package.json` covers the backend (Express, `node backend/server.js`)
- `ingestion-webapp/frontend/package.json` covers the React app (`react-scripts`)

Each tier must be verified independently.

### Backend gates

```bash
cd /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/vcon/vcon-ingestion/ingestion-webapp

# 1. Install (only if brief authorizes; node_modules may already exist)
npm install

# 2. Lint — workspace ships no eslint config today. If the brief introduces lint, it specifies the config; otherwise skip with explicit note in EVIDENCE.
#    Subagent NEVER adds a lint config without authorization.

# 3. Tests — workspace ships no test runner today. Baseline rule applies: any new behavior gets at least one test.
#    Brief specifies the harness (Jest, Mocha + supertest, node:test). The implementer adds it under authorization.

# 4. Smoke run — backend boots and binds the port
node -e "require('./backend/server.js')"   # or equivalent boot check
```

### Frontend gates

```bash
cd /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/vcon/vcon-ingestion/ingestion-webapp/frontend

# 1. Install (only if brief authorizes)
npm install

# 2. Tests (CRA / react-scripts)
CI=true npm test -- --watchAll=false

# 3. Build (this is the type-equivalent check — TypeScript is a devDep but most files are .js)
CI=true npm run build
```

**Baseline rule — no tests today**: the backend ships no tests; the frontend has the CRA scaffold but may have no real tests. If the brief introduces behavior, the implementer MUST add at least one test (backend: supertest or similar; frontend: react-testing-library). "Workspace had no tests, so I added none" is a contract violation.

**Tier-specific assertions**:

- **CORS preservation (backend)**: any change to `server.js` middleware MUST be followed by a smoke assertion confirming the allowed-origins list still matches the documented set (`localhost:8080`, `localhost:3000`, `localhost:3001`, `process.env.FRONTEND_URL`, `*.run.app` in prod). Implementer states "CORS list unchanged" or "CORS list changed: <diff>" in evidence.
- **Auth header passthrough (frontend)**: any new component that calls a protected backend endpoint MUST attach the `Authorization: Bearer <token>` header consistent with existing components. Tests assert the request shape.
- **Signed-URL flow integrity**: if the change touches `routes/signedUrl.js` or its caller, add a test that asserts the response shape (the frontend expects `{ url, fields }` or equivalent — confirm against existing handlers). Signed URLs are time-limited; tests must not depend on a specific expiry.
- **Build output sanity (frontend)**: any new component import MUST be verified by `npm run build` exiting clean. CRA's build is the TS / dependency-resolution gate for this workspace.

**Pre-flight gotchas**:
- The frontend is **React 19** with `react-scripts 5.0.1` (CRA). CRA is deprecated upstream — do NOT propose migrating to Vite or Next.js unless the brief explicitly authorizes it.
- The frontend mixes JS and TS (`typescript` is a `devDependency` but most files are `.js`). New files match the surrounding directory's language; do NOT mass-convert.
- Tailwind 3 is configured in `tailwind.config.js`; class additions don't require config changes unless the work introduces a new theme value.
- Backend boots on `process.env.PORT || 5000`. Tests must not hard-code the port.
- CORS allowlist filters falsy entries (`.filter(Boolean)`); a missing `FRONTEND_URL` env var silently drops production frontend origin. Tests covering CORS should set this env var explicitly.
- The backend talks to orchestrator's `auth-service` for token verification (JWKS) — local tests that exercise auth must mock the JWKS fetch.
- `package-lock.json` is committed at both root and `frontend/`; respect npm (not pnpm or yarn) as the package manager.

## Evidence shape (subagent returns)

1. **Status line** — `PASS` | `NEEDS REVIEW` | `BLOCKED`
2. **Summary** — three sentences
3. **Tier(s) touched** — `backend`, `frontend`, or `both`
4. **Endpoint or component** — restate from brief, confirm match in code
5. **Diff** — file paths with one-line summary per file
6. **Install strategy** — fresh `npm install` (if authorized) / existing `node_modules` reused
7. **Gate evidence**:
   - Backend: smoke-boot result, test exit code (if added)
   - Frontend: `npm test` exit code, test count, new test count; `npm run build` exit code
8. **Tier-specific assertion evidence** — per the assertion list above
9. **CORS / auth posture** — CORS list status, auth header status
10. **New tests added** — list with covered behavior
11. **Open questions**
12. **Proposed commit message**

## Output format (handoff)

```
STATUS: PASS | NEEDS REVIEW | BLOCKED
SUMMARY: <3 sentences>
TIER(S): backend | frontend | both
ENDPOINT/COMPONENT: <e.g. POST /api/batches/upload, or <SamplesPanel />>

DIFF:
- ingestion-webapp/backend/routes/signedUrl.js — <one-line summary>
- ingestion-webapp/frontend/src/components/SamplesPanel.jsx — <one-line summary>
- ...

INSTALL: <fresh / reused / brief-authorized>

GATES (BACKEND):
- smoke boot — pass / fail
- tests (if any) — exit 0, <N> tests, <M> new

GATES (FRONTEND):
- npm test — exit 0, <N> tests, <M> new
- npm run build — exit 0

TIER ASSERTIONS:
- CORS preservation: unchanged | changed: <diff>
- Auth header passthrough: <test name or "n/a — no protected call added">
- Signed-URL flow: <test name or "n/a — not touched">
- Build output sanity: <"clean" or "with warnings: <list>">

EVIDENCE:
<tool output excerpts>

NEW TESTS:
- backend/test/<name>.test.js — <behavior>
- frontend/src/__tests__/<name>.test.jsx — <behavior>

OPEN QUESTIONS:
- <or "none">

PROPOSED COMMIT:
<conventional commit message>
```

## Common failure modes

| Failure | Symptom | Mitigation in brief |
|---|---|---|
| Silent CORS allowlist change | Production frontend blocked from prod backend, or unknown origin accepted | Brief mandates CORS preservation assertion; subagent restates list status |
| Missing `Authorization` header on protected call | 401 on user click, generic error in UI | Brief mandates auth-header test on any new protected call |
| Signed-URL response shape drift | Frontend uploads fail with "unexpected response" | Test asserts response shape; brief flags if `{ url, fields }` is changing |
| CRA build breaks on TS / dep mismatch | Cloud Run image won't build | `npm run build` is mandatory; subagent confirms exit 0 |
| Hard-coded port in test | Test fails on CI / port collisions | Brief specifies dynamic port allocation |
| Auth JWKS fetched live in tests | Test depends on running auth-service | Tests mock JWKS fetch; brief calls this out |
| Tailwind class typos | Class silently ignored, layout breaks at runtime | Pre-flight: any new class without a corresponding `tailwind.config.js` entry is verified against the default Tailwind reference |
| Backend lint config silently introduced | Future PRs get noise from drive-by config | Subagent does NOT add lint config without authorization |

## Subagent does not

- Modify GCS bucket configuration or CORS scripts (`setup-cors.sh`, `update-bucket-cors.sh`) — Terraform / infra
- Modify Cloud Run service config (`cloud-run.yaml`, `deploy-cloud-run.sh`) — Terraform-owned
- Migrate frontend off Create React App — requires explicit Team-level decision
- Mass-convert frontend `.js` → `.tsx` — language mix is intentional
- Switch package managers (npm is authoritative; package-lock.json is committed at both levels)
- Add a new top-level route or component without authorization
- Modify the `auth-service` JWKS contract or `Authorization` header expectation — that's an orchestrator-cross-cutting change
- Run `npm install` with arbitrary new dependencies without explicit brief authorization
- Push, commit, or open PRs — Team owns the publish step

## Lessons embedded

- **The webapp is one Cloud Run service, two tiers.** Backend serves the built frontend in production; both tiers are in the same image. Tests run independently per tier.
- **Backend `package.json` lives at the workspace root**, not under `backend/`. `npm run start` points at `backend/server.js`.
- **CRA is deprecated upstream**, but in-place. Migration is a Team-level decision, not a subagent move.
- The frontend talks to the orchestrator's `auth-service` for JWKS. The webapp itself does NOT verify JWTs — it forwards the bearer token.
- CORS allowlist is **strictly enforced** in development and **permissive for `*.run.app`** in production. Changing the rule has security implications; the brief must justify any change.
- Backend ships no tests today; CRA frontend ships only the scaffold. Establishing baseline coverage when the brief authorizes it is in-scope work.
