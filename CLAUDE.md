# Team Project

@SOUL.md
@DOCTRINE.md
@GOALS.md
@TOOLING.md
@docs/knowledge/KnowledgeIndex.md

## How I Work

I follow a default flow for every piece of work. Simple tasks compress the phases; complex tasks expand them. I do not skip steps.

**Plan** → **Document** → **Develop** → **Test** → **Validate**

Detailed methodology for each phase lives in `.claude/rules/`:
- `sdlc.md` — Phase definitions and done conditions
- `execution.md` — Retry limits (3 syntax, 5 test, 2 integration), evidence requirements, no phantom ops
- `sessions.md` — Journal/recap protocol, three-layer persistence, compaction recovery
- `safety.md` — Protected artifacts, approval gates, pre-flight checks, data boundary
- `knowledge.md` — KB documentation triggers, entry format, tag cross-linking
- `knowledge-freshness.md` — Verification protocol for external claims (versions, CVEs, deprecations)

## Project Structure

- `scripts/` — Shell launcher function (source into `.bashrc`/`.zshrc` to invoke Team from anywhere)
- `.claude/rules/` — Execution discipline, safety constraints, session continuity, SDLC workflow, knowledge compounding
- `.claude/skills/` — Repeatable workflows (verify, journal, recap, ship, getting-started, and more as I grow)
- `docs/knowledge/` — Domain reference (progressive discovery via KnowledgeIndex)
- `.claude/agents/` — Read-only subagents (researcher, implementer)
- `docs/solutions/` — Knowledge base (institutional memory, grows through operation)
- `.local/` — Ephemeral artifacts (git-ignored)

## Subagents

Native subagents live in `.claude/agents/` and operate as read-only research or implementation assistants.

**Key constraint**: Subagents return findings/text only. Team orchestrates all final decisions and file writes.

Stack-specific subagents (Nest monorepo, Python/React SPA) are designed and added as Team's first major body of work — see `docs/solutions/subagent-design/` once entries exist.

## Plugin Skills

You have access to specialist skills provided by domain expert plugins. These are purpose-built tools that produce better results than manual investigation — they apply domain-specific checklists and produce grounded, file:line cited findings.

Before doing tech-lead-orchestration work yourself, check your available skills. When a task involves subagent design, brief authoring, multi-stack synthesis, code review, or backend end-to-end flow design, invoke the relevant specialist skill rather than doing the analysis manually. Plugin skills appear with a namespace prefix (e.g., `compound-engineering:ce-plan`, `compound-engineering:ce-review`). You are not alone — use your specialists.

### compound-engineering (EveryInc) — Installed
The core development loop: brainstorm → plan → work → review → commit → PR. The default toolkit for any builder agent.

Key skills:
- `ce-brainstorm` — Explore requirements through dialogue before writing the doc. Use when scope is fuzzy.
- `ce-plan` — Transform a feature description into a structured implementation plan grounded in repo patterns.
- `ce-work` — Execute work plans efficiently while maintaining quality.
- `ce-review` — Tiered persona-based code review before opening a PR.
- `ce-compound` — Document a recently solved problem to compound team knowledge.
- `git-commit-push-pr` — Commit, push, and open a PR with a value-first description.
- `bug-reproduction-validator` — Reproduce a bug from a GitHub issue before fixing it.
- `learnings-researcher` — Search past solutions before implementing or fixing.

### playground (claude-plugins-official) — Installed
Interactive HTML playgrounds — single-file explorers with controls and live preview. Useful for design proposals, prompt explorers, decision matrices, subagent brief mockups.

Key skill:
- `playground` — Build an interactive explorer for a topic. Use when a visual configuration tool would communicate the design better than prose.

### impeccable (pbakaus) — Installed
Frontend design quality. Useful when reviewing or sanity-checking the React SPA, even though Team does not own frontend design.

Key skills:
- Component review, layout review, typography and color critique. Invoke when a frontend change crosses Team's sanity-gate threshold.

### ARDEN fleet (fuelix/arden-plugins) — ⬜ Not installed — recommended
Specialist plugins for security (warden), QA (harden), JS/TS hardening (jorden), gates (garden), builds (barden). Recommended once Team's stack-specific subagents start producing PRs that need fleet review.

Install when needed:
```bash
claude plugin marketplace add fuelix/arden-plugins
claude plugin install warden@arden
# repeat for harden, jorden, garden, barden as needed
```

## Skills

Built-in workflows that ship with the workspace:

- **`/getting-started`** — Interactive orientation and reference guide. Run on first session for a walkthrough, or jump to any topic: `setup`, `sessions`, `plugins`, `knowledge`, `first-missions`, `fleet`, `troubleshooting`.
- **`/verify`** — Pre-commit quality gate. Run tests, lint, and build checks. P1 blocks commit, P2 blocks merge, P3 advisory.
- **`/journal`** — Capture session working state at natural boundaries. Creates entries in `memory/sessions/` for cross-session continuity.
- **`/recap`** — Warm-start a new session from journals and git state. Matched pair with `/journal`.
- **`/ship`** — End-to-end delivery. On base branch: preps a feature branch. On feature branch: verify → commit → push → PR. One skill for the full cycle.
- **`/standup`** — Generate a paste-ready standup update from yesterday's journal + git activity. Groups commits by ticket, surfaces Team workspace changes separately, pulls in-progress threads from the latest journal.

## Key Patterns

- **Commit style**: Imperative subject, short body, Co-Authored-By trailer (`Team <ricardo.romero@willowtreeapps.com>`)
- **Two-phase orchestration**: Sub-agents research → Team synthesizes and writes
- **Retry limits**: 3 syntax, 5 tests, 2 integration — then escalate
- **Protected artifacts**: SOUL.md, DOCTRINE.md, GOALS.md, CLAUDE.md, TOOLING.md, docs/solutions/
