# Next.js Web Subagent Brief

> Dispatch contract for Next.js 14 (App Router) web apps in `apps/*-web`. Primary target: `apps/aqm-web`.

## Scope & boundaries

**Owns**:
- Pages, layouts, route handlers under `src/app/`
- Components under `src/components/`, hooks under `src/hooks/`, utilities under `src/lib/`
- Middleware (`src/middleware.ts`) and instrumentation (`src/instrumentation.ts`)
- Unit/component tests with Vitest + Testing Library
- Smoke E2E tests via Playwright

**Does not own**:
- Visual design decisions — Team is a sanity gate, not the design owner. If a brief asks for new layouts/components from scratch, escalate to whoever owns frontend
- API contracts — those belong to the corresponding `*-api` and are dispatched there
- Auth strategy or session shape — auth changes touch `aqm-api` and possibly Cloud Functions; not a frontend-only dispatch
- Tailwind config or design tokens (`@fuelix/config-tailwind`, `packages/ui`) — shared package changes require Team review

## Input fields (Team's brief must include)

1. **Goal** — what changes, why, and what the user sees differently
2. **Workspace** — exact path, e.g. `apps/aqm-web`
3. **Touchpoints** — affected pages/components (best-effort)
4. **Acceptance criteria** — bulleted, each expressible as a Vitest assertion or a Playwright step
5. **Constraints** — what NOT to change (e.g. "do not introduce new shared components", "preserve existing route shape", "do not bump Next.js version")
6. **Test plan** — which Vitest tests, which Playwright spec files; whether a smoke E2E is required
7. **API dependencies** — which `*-api` endpoints this work consumes and whether their contract is stable. If the contract is in flight, Team writes a stub or fixture before dispatch
8. **Browser scope** — defaults to chromium-pr (Playwright project). Specify if other browsers matter
9. **Out of scope** — explicit list

## Mandatory verification gates

```bash
cd apps/<web-app-name>

# 1. Lint — Next ESLint config, 0 errors
pnpm run lint

# 2. Type-check
pnpm run type-check

# 3. Unit + component tests
pnpm run test
# Substantive UI changes:
pnpm run test:coverage

# 4. Production build — proves no Next.js runtime config errors
pnpm run build

# 5. Smoke E2E (REQUIRED for any change touching routes, middleware, or layout)
pnpm run test:e2e
# This uses --pass-with-no-tests, so the subagent MUST confirm at least one
# Playwright spec actually exercised the changed surface. "Passed with 0 tests"
# is NOT acceptance.
```

**Gate-skipping rule**: same as Nest API brief — silent skip is a contract violation.

**Pre-flight gotchas to encode in the brief**:
- Playwright requires browsers installed: `pnpm run playwright-install` once per workspace.
- `test:e2e` uses `--pass-with-no-tests` and `--project=chromium-pr`. If no spec matches the changed routes, the subagent must add one or declare "no E2E coverage available, manual smoke required" in evidence.
- Next.js production build fails on type errors and on missing required env (`NEXT_PUBLIC_*`). The brief must include the env stub.
- Server components vs. client components: `'use client'` matters. Misplacing it produces opaque build errors.

## Evidence shape (subagent returns)

1. **Status line** — `PASS` | `NEEDS REVIEW` | `BLOCKED`
2. **Summary** — three sentences max
3. **Diff** — file paths with one-line summary per file
4. **Test evidence**:
   - Vitest: last ~30 lines, exit code, count of passing/failing/new
   - Playwright: project run report, list of specs that exercised the change. If `--pass-with-no-tests` skipped everything, called out explicitly
5. **Lint output** — `0 errors, 0 warnings` or the offending lines
6. **Type-check output** — clean or the offending lines
7. **Build output** — Next.js build summary (route count, build time, no warnings)
8. **Visual confirmation** — for any visible UI change, the subagent describes what it looks like (e.g. "form now shows a validation error below the email field when submit is attempted with empty value"). Screenshots optional but encouraged when the change is non-trivial visually
9. **New tests added** — list of new Vitest/Playwright files and behavior covered
10. **Open questions**
11. **Proposed commit message**

## Output format (handoff)

```
STATUS: PASS | NEEDS REVIEW | BLOCKED
SUMMARY: <3 sentences>

DIFF:
- src/app/path/page.tsx — <one-line summary>
- ...

GATES:
- lint — exit 0, 0 warnings
- type-check — exit 0
- test (vitest) — exit 0, <N> tests
- test:e2e (playwright) — exit 0, <K> specs ran, <names>
- build — exit 0

EVIDENCE:
<tool output excerpts>

VISUAL:
<one-paragraph description of what changed visibly, or "no visible change">

NEW TESTS:
- src/components/foo.test.tsx — <behavior>
- e2e/foo.spec.ts — <flow covered>

OPEN QUESTIONS:
- <or "none">

PROPOSED COMMIT:
<conventional commit message>
```

## Common failure modes

| Failure | Symptom | Mitigation in brief |
|---|---|---|
| `--pass-with-no-tests` masks E2E gap | Gate green but no spec ran | Brief lists which Playwright specs the change must touch; subagent confirms by name |
| `'use client'` placement wrong | Build error or hydration mismatch | Test plan includes a render assertion in the right environment |
| Server component imports client-only lib | Build error referencing `next/headers` or similar | Brief notes whether the touched component is server or client |
| Env var missing at build | Build fails with `NEXT_PUBLIC_X is undefined` | Brief lists required env stubs |
| Middleware regex too greedy | Routes silently fail to render | Test plan adds an E2E that hits a route the middleware should NOT match |
| Tailwind class purged | Style missing in production build only | Avoid dynamic class names; if unavoidable, add to safelist (and call this out in the brief) |

## Subagent does not

- Modify `packages/ui` or `packages/config-tailwind` — shared package changes require Team review
- Add new top-level dependencies without explicit authorization
- Run `pnpm -w run format`
- Push, PR, or merge
- Make subjective design decisions — if the brief is ambiguous about visual intent, escalate

## Lessons embedded

- Next.js is pinned at 14.2 (App Router); React at 18. Do not propose React 19 features.
- Vitest 3 is the unit test runner; do not introduce Jest into the web workspace.
- Playwright tests exist; the subagent should prefer adding to existing specs over scaffolding new test infrastructure.
- Sentry and Vercel analytics ship in the bundle; new dependencies that bloat first-load JS need a justification.
