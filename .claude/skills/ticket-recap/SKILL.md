---
name: ticket-recap
description: Capture a structured one-page recap of the work done for a Jira ticket — scope, surface area, decisions, contracts, gotchas — so future questions about the ticket can be answered without a code deep-dive. Use when finishing a ticket (called by `/open-pr` automatically) or to backfill an already-shipped ticket. Triggers on `/ticket-recap`, `/ticket-recap AQ-123`, "recap this ticket", "save what we did on AQ-X".
version: 1.0.0
triggers:
  - /ticket-recap
  - /ticket-recap AQ-123
requires:
  - gh CLI authenticated as ricardoromero-wt (for PR data)
  - Atlassian MCP tools available (for Jira data)
  - Active branch must have a Jira ticket ID parseable from the branch name, OR ticket ID passed as an arg
---

# ticket-recap — Per-ticket Working Memory

## Purpose

Persist a tight, one-page recap of what was done for a ticket so that "what did we do on AQ-691?" is answered by reading **one file**, not by spelunking commits, PRs, and Jira comments.

The recap is **not** a dump. It captures the bits that don't survive in git/Jira on their own:
- The scope sentence (what problem was solved, in plain prose)
- Surface area (endpoints, files, schemas — pointers, not contents)
- Key decisions and what was rejected and why
- Contracts agreed with other teams (PR comments, Jira comments, schema mirrors)
- Gotchas worth a future 30 minutes

Anything fully reconstructable from `git log` / `gh pr view` is **excluded**. The recap is the synthesis layer.

---

## Storage Layout

```
docs/<project>/ticket-recaps/<TICKET-ID>.md
```

`<project>` is derived from the active repo's `origin` URL. For `git@github.com:fuelix/core.git` → `core`. New projects (e.g. `aqm-web` if it splits out, or future repos) get their own subdirectory automatically.

Recap files live in the **team workspace** repo (`~/Development/team`), not the source repo. They are **intentionally gitignored** (`.gitignore` excludes `docs/*/ticket-recaps/`) and never committed — they may contain company context the user prefers to keep off remote, even on internal repos. The skill machinery itself (this `SKILL.md`, the `/open-pr` integration) is tracked; the skill's *output* is local-only by design. Do not propose committing recap files unless the user explicitly says otherwise.

---

## Usage

```
/ticket-recap                  # derives ticket ID from current branch
/ticket-recap AQ-691           # explicit ticket ID
/ticket-recap AQ-691 --update  # regenerate (overwrites; default refuses if file exists)
```

Called automatically by `/open-pr` as its last step (see `open-pr/SKILL.md` Step 10).

---

## Execution Protocol

### Step 1 — Resolve ticket ID and project

```bash
# If arg passed, use it. Otherwise derive from branch.
TICKET="${1:-}"
if [ -z "$TICKET" ]; then
  BRANCH=$(git branch --show-current)
  TICKET=$(echo "$BRANCH" | grep -oE '^[A-Z]+-[0-9]+|/[A-Z]+-[0-9]+' | head -1 | tr -d '/')
fi

# Project name from origin URL: org/repo → repo
ORIGIN=$(git remote get-url origin)
PROJECT=$(echo "$ORIGIN" | sed -E 's|.*[:/]([^/]+)/([^/.]+)(\.git)?$|\2|')
```

If `$TICKET` is empty after this, stop and ask the user for an explicit ID.

### Step 2 — Refuse-overwrite check

```bash
TARGET="$HOME/Development/team/docs/$PROJECT/ticket-recaps/$TICKET.md"
if [ -f "$TARGET" ] && [ "${UPDATE:-0}" != "1" ]; then
  echo "EXISTS: $TARGET"
  # Show first 30 lines and stop, telling the user to pass --update if they want to regenerate
fi
```

### Step 3 — Gather inputs in parallel

Run these concurrently and collect output:

1. **Branch + commits**:
   ```bash
   git log main..HEAD --pretty=format:'%h %s' && git log main..HEAD --pretty=format:'%h%n%B%n---' --no-merges
   ```
2. **File-change summary**:
   ```bash
   git diff main..HEAD --stat
   ```
3. **PR data** (if a PR exists for the branch):
   ```bash
   GITHUB_TOKEN="" gh pr list --head "$BRANCH" --state all --json number,url,title,body,state,isDraft --limit 1
   GITHUB_TOKEN="" gh pr view <PR#> --comments --json comments  # capture cross-team contract comments
   ```
4. **Jira ticket** via Atlassian MCP:
   ```
   getJiraIssue(cloudId="fuelix.atlassian.net", issueIdOrKey=$TICKET, responseContentFormat="markdown")
   ```
   Capture: summary, issueType, description, status, issuelinks (especially "is cloned by" / "blocks" relationships).

### Step 4 — Synthesize the recap

Use the **template** (Appendix A). Fill it from the gathered inputs. Apply these rules:

- **Scope sentence**: one sentence, plain prose, names the problem solved. *Not* the Jira summary verbatim.
- **Surface area**: file:line citations only — never paste code.
- **Decisions**: each line follows the shape `Decision: X because Y. Rejected: Z because W.` Skip the section if there were no genuine forks.
- **Contracts**: cross-team agreements only. If the FE consumed a schema, link the PR comment / Jira comment that committed the contract.
- **Gotchas**: things a future reader would burn time rediscovering — environmental quirks, non-obvious failure modes, "we tried X first and it didn't work because..."
- **Links**: PR, Jira, any related tickets (clones, blockers).

Skip empty sections. Better an honest 4-section recap than a padded 7-section one.

### Step 5 — Write the file and report

```bash
mkdir -p "$(dirname "$TARGET")"
# Write the synthesized markdown to $TARGET
```

Report:
```
Recap written:
  Path:    docs/core/ticket-recaps/AQ-691.md
  Ticket:  AQ-691 — [BE] Add Interaction Count to Agent Performance Breakdown
  PR:      https://github.com/fuelix/core/pull/8561
  Status:  In Progress (PR draft)
```

---

## Appendix A — Template

```markdown
---
ticket: <TICKET-ID>
title: <Jira summary, cleaned>
project: <project name>
status: <Jira status — Open|In Progress|Done|Blocked|...>
pr: <PR URL or "none">
branch: <branch name>
date: <YYYY-MM-DD of last commit>
related: [<related-ticket-ids, e.g. AQ-694 (FE)>]
---

# <TICKET-ID> — <Jira summary, cleaned>

**Scope**: <one sentence in plain prose. What problem did we solve?>

## Surface area

<Bulleted list of touch points. file:line citations only — pointers, not contents.>

- `apps/aqm-api/src/.../foo.ts:84` — what changed in this file, in 1 line
- `packages/aqm-database/prisma/migrations/20260504.../migration.sql` — short purpose

## Decisions

<Each entry: decision + alternative rejected + why. Skip section if no real forks.>

- **Compute interactionCount inside the existing CTE** rather than a second query. Rejected: separate `COUNT(*)` query — would double the round-trips for zero new information; the CTE already groups by agent.

## Contracts

<Cross-team agreements that don't live in the diff. PR comments, Jira comments, schema mirrors.>

- FE/BE schema agreed on AQ-691 comment 89577. AQ-694 (FE) consumes `interactionCount: number`.

## Gotchas

<Things a future reader would burn time on if they didn't know.>

- `@fuelix/nestjs` builds with raw `tsc`; `spoof-token.json` is **not** copied to `dist/`. Local API silently 401s on every spoof token until you `cp src→dist`.

## Links

- PR: <url>
- Jira: <url>
- Related: <links to related tickets>
```

---

## Failure Modes

| Failure | Cause | Recovery |
|---------|-------|----------|
| No ticket ID in branch name | Branch named without prefix | Ask user for the ID explicitly |
| Recap file already exists | Ticket recapped previously | Show first lines, ask whether to `--update` |
| Jira fetch fails | Auth/network | Proceed with PR + git data, note "Jira fetch failed" in the recap header |
| No PR yet | Recap requested before PR open | Skip PR section, note "PR pending" |
| Project dir doesn't exist yet | First ticket in a new project | `mkdir -p` and continue |

---

## Integration

- **`/open-pr` calls this as its final step** (see `open-pr/SKILL.md` Step 10). Failure of `ticket-recap` does **not** roll back the PR; the recap is best-effort.
- **Lookup**: when the user asks "what did we do on AQ-691?", read `docs/<project>/ticket-recaps/AQ-691.md` first; fall back to `gh pr list --search` + `git log --grep` if the file is missing.

---

## Safety Constraints

- **Never include credentials, tokens, or production URLs in the recap.** Spoof tokens, even though they're dev-only, get redacted to `<SPOOF_TOKEN>` placeholders.
- **Never auto-commit the recap file.** The user owns commits to the team workspace. Write the file, report the path, let them stage/commit.
- **Never overwrite an existing recap** without `--update`. Old recaps are read-only history; intentional regeneration is opt-in.
