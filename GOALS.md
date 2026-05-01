# Goals

Prioritized objectives for our current work. Each goal follows Commander's Intent format: Purpose (why), End State (what done looks like), Appetite (how much it's worth), No-gos (explicit exclusions). Top-to-bottom priority ordering.

---

### Subagent Fleet Build-out
**Purpose**: Establish a reliable pattern of stack-specific subagents that deliver end-to-end backend changes with minimal handholding from Team. The orchestrator pattern only compounds value when subagents actually exist and actually carry weight.
**End State**: Subagent definitions exist for the Nest monorepo and the Python/React SPA. Each has a documented brief format, mandatory verification gates it must pass, and an evidence bar Team trusts (test output, diff, lint clean). Team can dispatch a brief and reliably receive a PR ready for review.
**Appetite**: Primary initiative — initial bring-up over weeks; per-stack capability expands as recurring gaps surface in operation.
**No-gos**: Not building one mega-subagent that "does everything." Not letting subagents merge without verification gates. Not duplicating cross-cutting logic across subagents — extract to a shared rule first.

---

### Backend End-to-End Ownership
**Purpose**: Own the design and verification of backend flows that span services, schemas, and queues — the work no single repo's tests catch alone. The cross-service surface is where the most expensive bugs live and where no individual subagent has full sight.
**End State**: Documented flow specs for the most-touched cross-service journeys, each backed by an integration or contract test that fails when the flow breaks. Outage-driven gaps generate new specs, not postmortem-only entries.
**Appetite**: Ongoing — incremental alongside other work, weighted toward high-traffic flows. Plumbing changes get a lighter review; new feature flows get the full treatment.
**No-gos**: Not blocking PRs on flow docs that don't exist yet — backfill, don't gate. Not boil-the-ocean documentation across every flow. Not owning frontend flows past the integration boundary.

---

### Frontend Sanity Gates
**Purpose**: Catch obvious React-SPA regressions (broken build, type errors, smoke-path failures) without taking ownership of frontend design. The goal is a floor, not a ceiling.
**End State**: Type check, build, and a single smoke E2E run as required gates on the SPA's PRs. Team comments on visible UX regressions (broken nav, blank screens, console errors) but defers design decisions to whoever owns frontend.
**Appetite**: Secondary — low-touch maintenance, invest only when something breaks, then encode the lesson.
**No-gos**: Not designing components. Not redrawing layouts. Not blocking a PR on subjective UI taste.
