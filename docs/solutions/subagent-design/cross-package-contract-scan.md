---
title: Shared schemas in monorepo packages are first-class contract touchpoints
date: 2026-05-04
category: subagent-design
severity: P1
tags: [aqm-api, common-types, contracts, cross-package, dispatch, brief-design]
resolved: true
---

## Problem

The AQ-691 implementer brief authorized work in `apps/aqm-api` plus a single Prisma migration in `packages/aqm-database`. The work shipped end-to-end broken: the BE returned a new `interactionCount` field correctly, but the FE Zod parser silently stripped it because the source-of-truth schema in `packages/common-types/src/aqm/schemas/analytics/index.ts` did not declare the field. The dashboard column would have rendered `undefined` for every row.

The bug only surfaced when a parallel implementation existed (the team's `core-aq691-be-interaction-count` worktree) and the user asked for a comparison. Without that comparison, the broken implementation would have shipped.

## Context

- Monorepo: `fuelix/core` (pnpm + turbo)
- Stack: NestJS 11 BE (`apps/aqm-api`), Next.js 14 FE (`apps/aqm-web`), shared types in `packages/common-types`
- Affected schema: `aqmAgentsAnalyticsSchema` at `packages/common-types/src/aqm/schemas/analytics/index.ts:183`
- Consumer: `apps/aqm-web/src/lib/api/analytics.ts:77` parses API responses against this schema before passing them to React components
- Ticket: AQ-691 (BE) with sibling AQ-694 (FE)

## Investigation

The researcher dispatched against AQ-691 cited the BE thoroughly — controller at `analytics.controller.ts:298`, service, repository, mapper, viewmodel, domain Zod schema — but never grepped `packages/common-types` for the response shape, and never searched `apps/aqm-web` for consumers. The brief inherited that scope and authorized the implementer to touch `apps/aqm-api` and one migration file only.

The implementer faithfully executed the brief and shipped a passing build with green gates. The contract violation was invisible to both the BE test suite (mocked at the Prisma level) and the BE build (no `packages/common-types` import in the response path).

The gap was discovered by reading the parallel implementation, which touched 8 files across 3 workspaces — including the `packages/common-types` schema and two `apps/aqm-web` test fixtures.

## Solution

Two prevention edits to encoded artifacts:

1. **All four brief templates** — `nest-api-brief.md`, `next-web-brief.md`, `nest-worker-brief.md`, `cloud-function-brief.md` — gained a mandatory "Cross-package touchpoints" input field. When the work changes a contract that crosses the workspace boundary (API response shape, message shape, Firestore document shape, etc.), the brief MUST list the source-of-truth schema in `packages/common-types/` and any consumer fixtures in adjacent workspaces as authorized writes. Default is empty; silence on this section means "no cross-package writes allowed." Each brief's "Subagent does not" section gained a parallel constraint forbidding the implementer from inferring cross-package authorization.

2. **All four researcher agents** — `aqm-api-researcher.md`, `aqm-web-researcher.md`, `vcon-worker-researcher.md`, `cloud-function-ts-researcher.md`, `cloud-function-python-researcher.md` — gained a "Cross-Package Contract Scan" step that fires on every contract-changing investigation. Researcher must `grep` `packages/common-types/` for related Zod schemas, `grep` `apps/` and `firebase/functions/` for consumers, then report file:line for each. Silence on the scan is treated as a contract violation; researcher must explicitly state "no shared schema covers this contract" if the scan returned nothing. The Python Cloud Function researcher's variant additionally flags that Python hand-mirrors TS schemas and contract drift is invisible at compile time.

The patch to AQ-691 itself: added the field to the common-types schema, updated two FE test fixtures, made the BE viewmodel field `@ApiPropertyOptional` (since the same DTO is shared with a legacy endpoint that doesn't populate it), and added a controller-level e2e test proving the field round-trips through the stack.

## Trade-offs

**Gained**: Researcher now produces a more complete touchpoint map; brief now declares cross-package authorization explicitly. Implementers no longer need to infer or ask.

**Given up**: Each API-contract investigation costs an extra 1–2 grep passes in the researcher. For non-contract investigations (refactors, perf work, internal-only changes), the new section is empty and adds zero overhead.

**Not given up**: The implementer's narrow workspace authorization is preserved. The brief still says "do not touch `packages/` unless explicitly listed" — the change is to the listing process, not to the trust model.

## Verification

- Patched AQ-691 implementation passes all `apps/aqm-api` gates (lint, type-check, test, build) and the `apps/aqm-web` gates that touched files contribute to (rendering test passes with the new fixture)
- The `packages/common-types` build is clean
- The contract-level controller test asserts `interactionCount` round-trips through the BE stack
- FE Zod parser at `apps/aqm-web/src/lib/api/analytics.ts:77` now surfaces the field instead of stripping it (verified by reading the schema; FE consumes it at runtime)

## Lessons Learned

1. **Shared monorepo schemas are first-class contract touchpoints.** They are not "schema changes" in the Prisma migration sense, but they ARE contract changes — and contract changes must be reflected in every consumer the package serves.

2. **A passing CI run is not proof of end-to-end correctness when the contract crosses package boundaries.** The BE test suite mocked Prisma; it could not see the FE Zod parser. Cross-package wiring needs a test that exercises the actual contract — for response shapes, that means a controller-level e2e test plus FE fixture validation.

3. **The brief was the failure point, not the implementer.** The implementer executed exactly what was asked. A narrowly-scoped brief that misses a real touchpoint produces narrowly-scoped work that ships broken. Doctrine #2 ("80% planning, 20% execution") earned in blood here — the planning phase needed a cross-package scan it didn't run.

4. **Parallel implementations are a useful diagnostic.** The bug only surfaced because the team had already started the same work in a separate worktree and the user asked for a comparison. In the absence of a parallel implementation, the same bug would have shipped to staging.

5. **Encode the lesson where it gets read.** Saving this entry and updating the brief and researcher protocol is the institutional fix. Memory and conversation context evaporate; encoded protocol survives session boundaries and applies to every future dispatch.
