# Nest API Subagent Brief

> Dispatch contract for HTTP API services built on NestJS in `apps/*-api`. Primary target: `apps/aqm-api`.

## Scope & boundaries

**Owns**:
- Controllers, services, modules, DTOs, guards, interceptors, filters under `src/`
- Prisma schema reads (treats `packages/aqm-database/prisma/schema.prisma` as source of truth)
- Unit tests (`*.spec.ts`) and integration/e2e tests using NestJS testing module + supertest
- Wiring: GCP clients (Firestore, Pub/Sub, Cloud Tasks, Storage), Sentry, Unleash, observability

**Does not own**:
- Prisma schema *changes* or migrations — those touch shared `packages/aqm-database` and require Team review
- Cross-service contracts — if the brief implies a request/response shape consumed by another service, Team writes the contract test
- Infra (Terraform, GCP IAM, secret rotation) — out of scope, escalate to Team
- Front-end clients to this API — separate dispatch via `next-web-brief.md`

## Input fields (Team's brief must include)

1. **Goal** — one paragraph: what changes, why, and what observable behavior proves it
2. **Workspace** — exact path, e.g. `apps/aqm-api`
3. **Touchpoints** — files/modules expected to change (best-effort guess, not binding)
4. **Acceptance criteria** — bulleted list of testable behaviors. Each criterion must be expressible as a passing test
5. **Constraints** — what NOT to change (e.g. "do not modify the Prisma schema", "do not introduce new external services", "preserve the existing OpenAPI contract on `POST /vcons`")
6. **Test plan** — which tests will be added or updated; whether new fixtures or seed data are required
7. **Environment notes** — any non-default `.env.local` values the work depends on; whether the local Postgres/Firebase emulator must be running
8. **Out of scope** — explicit list of things to leave alone, especially adjacent code that "looks similar"

## Mandatory verification gates

The subagent MUST run all of the following from the workspace directory and capture exit codes. Any non-zero exit is a blocker.

```bash
cd apps/<service-name>

# 1. Prisma client must be regenerated against the current schema before tests
pnpm run prisma:generate                                # or rely on pretest hook

# 2. Lint — 0 errors, 0 warnings
pnpm run lint

# 3. Type-check
pnpm run type-check

# 4. Tests — full suite, not --testPathPattern. Coverage delta documented if applicable.
pnpm run test
# OR for substantive changes:
pnpm run test:coverage

# 5. Build — proves the code compiles for production
pnpm run build
```

**Gate-skipping rule**: if any gate is skipped (e.g. test pre-existing flake), the subagent declares it explicitly in the evidence section with the failing test name and Team decides whether to accept. Silent skipping is a contract violation.

**Pre-flight gotchas to encode in the brief**:
- `pretest` runs `prisma generate`. If `prisma:generate` fails, tests will fail with `@prisma/client did not initialize yet` — fix the generate step first.
- `aqm-api` test script runs `check-and-copy-env.ts` first; missing `.env.local` will fail before any test runs.
- Tests may depend on a running local Postgres (typically via `docker-compose.yml` at the monorepo root) and Firebase emulators.

## Evidence shape (subagent returns)

A single response containing:

1. **Status line** — one of: `PASS` (all gates green) | `NEEDS REVIEW` (gates green but Team should look at a decision) | `BLOCKED` (a gate failed and the subagent could not resolve)
2. **Summary** — three sentences max: what was done, what was not done, why
3. **Diff** — file paths changed with one-line summary per file. Full unified diff attached or referenced by branch
4. **Test evidence** — last ~30 lines of test output for each gate that ran, including the exit code line. Failing test names listed verbatim
5. **Lint and type-check output** — confirmation `0 errors, 0 warnings` or the offending output
6. **Build output** — `nest build` success line or error
7. **New tests added** — list of new `*.spec.ts` files and the behavior each covers
8. **Open questions** — anything the subagent assumed because the brief was ambiguous; anything Team should verify before merging
9. **Proposed commit message** — Conventional Commit format, no Co-Authored-By trailer (Team adds those at commit time)

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
- build — exit 0

EVIDENCE:
<tool output excerpts, exit codes visible>

NEW TESTS:
- src/path/to/feature.spec.ts — covers <behavior>

OPEN QUESTIONS:
- <bulleted, or "none">

PROPOSED COMMIT:
<conventional commit message>
```

## Common failure modes (encode in the brief if relevant)

| Failure | Symptom | Mitigation in brief |
|---|---|---|
| Prisma client stale after schema bump | Test compile error referencing old field | Brief specifies "run `prisma:generate` before tests" |
| `.env.local` missing or stale | `check-and-copy-env.ts` fails before any test | Brief lists required env vars; subagent asserts presence |
| Forgotten module registration | New service compiles but is undefined at runtime | Test plan requires an integration test that hits the controller via supertest |
| GCP client called without emulator host set | Test hangs on real Pub/Sub | Brief specifies `PUBSUB_EMULATOR_HOST` or mocks the client |
| Sentry/observability noise in test output | False positives in CI logs | Brief specifies test-mode init or `Sentry.init` mocking |
| Contract drift with `aqm-web` | Web build passes locally, fails on integration | If the change is endpoint-shape, Team writes a contract test before dispatch |

## Subagent does not

- Run `pnpm -w run format` or any repo-wide auto-fix
- Modify files outside the workspace unless the brief explicitly authorizes it
- Bump dependencies unless the brief explicitly authorizes it
- Push to a branch, open a PR, or invoke any GitHub action
- Touch secrets, IAM, or production config

## Lessons embedded

These came from recon of the monorepo. Update when reality changes.

- The workspace uses NestJS 11; `@nestjs/cli` is pinned at v10. Quirks of the v10 CLI against v11 runtime are documented in shared `packages/nestjs/` — read before fighting unexpected build errors.
- `@fuelix/server-observability` self-imports at top of `main.ts`. Do not reorder imports above it.
- Prisma is at major version 6. The `@prisma/client` import should not be replaced with raw SQL without a clear reason in the brief.
