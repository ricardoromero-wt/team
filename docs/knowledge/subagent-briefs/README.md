# Subagent Brief Templates

> Dispatch contracts for Team's stack-specific subagents. Each template defines what Team puts into a brief and what the subagent must return as evidence.

Team operates against a single TypeScript-first monorepo (`fuelix/core`, pnpm + turbo, Node 20+). Within that monorepo there are four execution shapes; each has its own brief because each has different verification gates and failure modes.

## Pick the right brief

| If the work is in… | Use this brief | Examples |
|---|---|---|
| `apps/aqm-api`, any other `apps/*-api` | [`nest-api-brief.md`](./nest-api-brief.md) | aqm-api, ex-api, admin-api, agent-trainer-api |
| `apps/aqm-web`, any other `apps/*-web` | [`next-web-brief.md`](./next-web-brief.md) | aqm-web, core-web, admin-portal |
| `apps/vcon-worker`, any other Cloud Run worker | [`nest-worker-brief.md`](./nest-worker-brief.md) | vcon-worker, bulk-processing |
| `firebase/functions/typescript`, `firebase/functions/python` | [`cloud-function-brief.md`](./cloud-function-brief.md) | scheduled functions, HTTP functions, pub/sub triggers, Cloud Scheduler |

If a change spans more than one shape, dispatch one brief per shape and synthesize on return. Cross-shape work is Team's job, not a single subagent's.

## What every brief shares

All briefs follow the same five-section structure so dispatch is predictable:

1. **Scope & boundaries** — what the subagent owns vs. what Team owns
2. **Input fields** — what Team must include in the brief for the work to be doable
3. **Mandatory verification gates** — commands the subagent must run successfully before returning
4. **Evidence shape** — the proof the subagent returns to Team
5. **Output format** — the structure of the handoff

## What every brief enforces

- **App-scoped commands only.** `pnpm --dir <workspace> run <task>`. No `pnpm -w run …` in feature work — see `AGENTS.md` in the monorepo root.
- **Lint and type-check are non-negotiable.** 0 errors, 0 warnings. This is repo policy, not Team's preference.
- **Verification before claim.** "It should work" is not evidence. Tool output with exit codes is.
- **Conventional Commits.** Subagents propose commit messages; Team writes the actual commit.
- **Subagents do not push, merge, or open PRs.** They return a diff + evidence. Team owns the publish step.

## Versioning

These templates evolve as Team learns. Treat them as the contract at the time of dispatch. When a gate proves insufficient (a category of bug slipped past), update the relevant brief and capture the lesson in `docs/solutions/subagent-design/` so the change has a documented reason.
