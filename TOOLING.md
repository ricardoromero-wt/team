# Tooling Guide

This guide covers the tools, plugins, and utilities available to Team. Use it to set up your environment and to help your owner install recommended tooling when they ask.

## Essentials (Ships with Workspace)

These are built in and ready to use — no installation needed.

### Built-in Skills
| Skill | Command | Purpose |
|-------|---------|---------|
| Orientation | `/getting-started` | Interactive walkthrough and reference guide |
| Quality gate | `/verify` | Pre-commit checks (tests, lint, build) |
| Session capture | `/journal` | Save working state at session boundaries |
| Session restore | `/recap` | Warm-start from journals and git state |
| Delivery | `/ship` | Branch → verify → commit → push → PR |
| Standup | `/standup` | Daily digest from journal + git activity, grouped by ticket |
| Ticket recap | `/ticket-recap` | Per-ticket recap (scope, decisions, contracts, gotchas) saved under `docs/<project>/ticket-recaps/`; auto-called by `/open-pr` |

### Subagents
| Agent | Role | Tools |
|-------|------|-------|
| Researcher | Read-only investigation (local-first, then external) | Read, Grep, Glob, WebFetch, WebSearch |
| Implementer | Code from specs (read before write, follow patterns) | Read, Grep, Glob, Write, Edit, Bash |

### Session Continuity
- **Journals** → `memory/sessions/` (rolling weeks)
- **Stable memory** → `memory/` (indefinite)
- **Knowledge base** → `docs/solutions/` (permanent, repo-tracked)

## Recommended Plugins

### compound-engineering (EveryInc)
**Description**: The core development loop — brainstorm, plan, work, review, commit, PR, ideate. Essential toolkit for any builder agent.
**Install**:
```bash
claude plugin install compound-engineering
```
**Key skills**:
- `ce-brainstorm` — Explore requirements through dialogue. Use when scope is fuzzy and a feature needs framing.
- `ce-plan` — Transform a feature description into a structured implementation plan. Use when requirements are roughly defined.
- `ce-work` — Execute work plans while maintaining quality. Use during implementation.
- `ce-review` — Tiered persona-based code review. Use before opening a PR.
- `ce-compound` — Document a recently solved problem. Use after non-obvious debugging.
- `git-commit-push-pr` — Commit, push, and open a PR with a value-first description.
- `bug-reproduction-validator` — Reproduce a bug from a GitHub issue. Use before attempting a fix.
- `learnings-researcher` — Search past solutions in `docs/solutions/`. Use before implementing.

### playground (claude-plugins-official)
**Description**: Interactive HTML playgrounds — single-file explorers with controls and live preview. Useful for design proposals, prompt explorers, decision matrices.
**Install**:
```bash
claude plugin install playground
```
**Key skills**:
- `playground` — Build an interactive explorer for a topic. Use when a visual configuration tool would communicate the design better than prose. Subagent brief mockups, dispatch flowcharts, and trade-off matrices are good fits.

### impeccable (pbakaus)
**Description**: Frontend design quality — component review, layout, typography, color, accessibility critique.
**Install**:
```bash
claude plugin install impeccable
```
**Key skills**:
- Frontend review skills — invoke when a React SPA change crosses Team's sanity-gate threshold (broken nav, console errors, blank states). Defer to whoever owns frontend on subjective design decisions.

### ARDEN fleet — ⬜ Not installed — recommended
**Description**: Specialist plugins for security (warden), QA (harden), JS/TS hardening (jorden), gates (garden), builds (barden). Recommended once Team's stack-specific subagents start producing PRs that need fleet review.
**Install** (when needed):
```bash
claude plugin marketplace add fuelix/arden-plugins
claude plugin install warden@arden
claude plugin install harden@arden
claude plugin install jorden@arden
claude plugin install garden@arden
claude plugin install barden@arden
```
**Key skills** (per plugin):
- `warden:*` — Security review skills. Use on PRs touching auth, secrets, or external surfaces.
- `harden:*` — QA and coverage skills. Use to enforce a quality floor on subagent output.
- `jorden:*` — JS/TS hardening. Use for type-safety and TS-config audits in the SPA.
- `garden:*` — Documentation and stale-content detection. Use periodically on `docs/`.
- `barden:*` — Build, dependency, and CI hygiene. Use on infra-touching PRs.

## Optional Tools

### QMD — Semantic Markdown Search (Recommended for Team)
Search your knowledge base by concept, not just keyword. Essential as `docs/solutions/` grows past 10–20 entries — Team operates across two stacks and a tech-lead role, so the KB will compound fast.
```bash
brew install qmd    # or: cargo install qmd
qmd index .         # Index the workspace
qmd search "how to handle a flaky integration test in Nest"  # Semantic search
```
**When to use**: Prefer `qmd search` over grep when searching KB entries by concept rather than exact term. Especially valuable as `docs/solutions/` grows past 20 entries.

### Playwright MCP — Browser Automation (Optional, for SPA sanity checks)
Navigate pages, take screenshots, fill forms, click elements. Useful for the occasional smoke test of the React SPA when something breaks and Team needs a visual confirmation.
```bash
claude mcp add playwright npx '@playwright/mcp@0.0.68'
```
**When to use**: When sanity-checking SPA behavior after a backend change that flows through. Not for ongoing frontend testing — that lives with the SPA's own test suite.

## Plugin Management Reference

### Listing installed plugins
```bash
claude plugin list
```

### Installing a direct plugin
```bash
claude plugin install <plugin-name>
```

### Installing from a marketplace
Some plugins are distributed through marketplaces. You must add the marketplace first, then install the plugin with a flavor suffix:
```bash
# Step 1: Add the marketplace (one-time)
claude plugin marketplace add <org>/<marketplace-name>

# Step 2: Install the plugin with @flavor
claude plugin install <plugin-name>@<flavor>
```

### Checking plugin health
If a plugin skill isn't being invoked, verify:
1. Plugin is installed: `claude plugin list`
2. CLAUDE.md has the "you are not alone" instruction with skill descriptions
3. Skill descriptions follow the pattern: `[what it does]. Use when [scenario].`

## Helping Your Owner

When your owner asks about tooling setup, installing plugins, or configuring tools:

1. **Check this guide first** — the install commands are here
2. **Show commands and ask before running** — present the install command to your owner and get confirmation before executing
3. **Verify success** — `claude plugin list` after install, `which qmd` for CLI tools
4. **Suggest updates** to this file for your owner to review — TOOLING.md is a protected artifact, modifications require approval
