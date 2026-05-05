---
name: standup
description: Generate a paste-ready standup update from yesterday's journal, commits, and ticket activity. Use when drafting a daily standup summary.
argument-hint: "[date] — yesterday (default), monday, last-friday, or YYYY-MM-DD"
---

# Standup — Daily Update Generator

## Purpose

Synthesize a paste-ready standup update from session journals plus git activity across all working repos. Groups commits by ticket, flags Team workspace changes separately, surfaces in-progress threads from the latest journal.

> "The journal already wrote down what yesterday looked like. Read it, don't reconstruct it."

## Safety Constraints

### NEVER
- Modify journals, commits, or any files (read-only)
- Fabricate ticket activity, PRs, or commits not present in evidence
- Include credentials, tokens, or sensitive data from journal entries

### ALWAYS
- Resolve relative dates (`yesterday`, `monday`) into absolute YYYY-MM-DD before querying
- Cite commit SHAs and PR numbers verbatim — never paraphrase
- Display the output as a markdown block the user can copy directly
- Note gaps explicitly (no journal for that date, no commits in repo X)

## Known Failure Modes

| Failure | Cause | Recovery |
|---------|-------|----------|
| No journal for target date | Day off, or journal not written | Fall back to git activity only; note absence |
| Multiple journals for same date | Mid-session checkpoints | Read all of them, dedupe content |
| Repo path missing or not a git repo | Working dir not configured | Skip with "unavailable" note, continue |
| Commits without ticket prefix | Refactors, fixes, chores | Bucket as "Other / chores" — don't drop them |
| Author identity mismatch | git config differs across repos | Use `--author=$(git config user.email)` per repo |
| Weekend or holiday | No activity on target date | Empty template, suggest the prior workday |

## Execution Protocol

### Step 1: Resolve Target Date

Parse the argument:
- No argument → yesterday (`date -v-1d +%Y-%m-%d` on macOS, `date -d yesterday +%Y-%m-%d` on Linux)
- `monday`, `friday`, etc. → most recent past occurrence of that weekday
- `YYYY-MM-DD` → use as-is

Save target date as `$DATE` for downstream steps.

- **Expected output**: A single ISO date string
- **Failure recovery**: If parsing fails, ask the user to specify YYYY-MM-DD

### Step 2: Locate Journal Entries

Find journals matching the target date in `memory/sessions/`:

```bash
ls memory/sessions/${DATE}-*.md 2>/dev/null
```

If multiple files exist, read all of them — mid-session checkpoints contain unique content.
If none exist, note "No journal entry for $DATE" in the output and continue.

- **Expected output**: List of journal files (possibly empty)
- **Failure recovery**: Continue without journals — git activity alone is still useful

### Step 3: Identify Repos to Scan

Default scan list:

1. **Team workspace** — the repo containing this skill (always scan)
2. **Primary work repo** — `~/Documents/ClientProjects/SE/Fuel/core`
3. **Session additional directories** — any path the current session lists as a working directory

If a path is not a git repo or doesn't exist, skip with a note. If both default repos are unavailable, ask the user which repos to scan.

- **Expected output**: List of valid repo paths
- **Failure recovery**: Prompt the user

### Step 4: Gather Git Activity Per Repo

For each repo, run in parallel:

```bash
cd $REPO && git log \
  --since="${DATE} 00:00" \
  --until="${DATE} 23:59" \
  --author="$(git config user.email)" \
  --pretty=format:"%h|%s|%an" \
  --no-merges
```

Parse each line into `{sha, subject, author}`. Detect ticket prefix via regex:

```
(PHX|ATL|FUEL|AQ|EX|PLAT|CORE)-\d+
```

Also surface any open PRs referenced in the journal (`gh pr view` on PR numbers found in journal text — informational only, do not block on failure).

- **Expected output**: Per-repo list of commits with parsed ticket IDs
- **Failure recovery**: If `git log` errors, mark the repo unavailable; continue

### Step 5: Group and Classify

Bucket commits:

1. **By ticket** (work repos only) — group all matching commits under each ticket ID
2. **Team workspace** — every commit in the Team repo, regardless of ticket. These are "new features added to Team" (skills, agents, rules, briefs, KB entries)
3. **Other / chores** — commits in work repos without a ticket prefix

For each ticket bucket capture: ticket ID, commit SHAs, subject lines, repo names.

### Step 6: Extract In-Progress Threads

From the latest journal for `$DATE` (or the most recent prior journal if none exists for that date), extract:

- `## Next` section — each line becomes an in-progress item
- `## Open question` or `## Open follow-up` (if present) — surface as open threads
- Filter out items already shipped (commit appears in Step 5 evidence)

If no journal exists, set in-progress to "Nothing recorded — fill in manually."

- **Expected output**: List of in-progress items and open threads
- **Failure recovery**: Note absence and skip the section

### Step 7: Compose and Display Standup

Display inline (do not write to a file). Format:

```markdown
## Standup — {weekday}, {YYYY-MM-DD}

### Yesterday
**{TICKET-ID}** — {one-line summary}
  - `{sha}` {commit subject} _(repo)_
  - PR: #{number} ({state})  ← if surfaced from journal or `gh`

**Other / chores**
  - `{sha}` {commit subject} _(repo)_

### Team workspace changes
- `{sha}` {commit subject}

### In progress
- {item from journal Next}
- {open question or thread}

### Today
- _<your plan here>_
```

Conventions:
- Tickets ordered by commit count (descending), then alphabetically by ID
- "Team workspace changes" section omitted if no commits in Team repo
- "Other / chores" section omitted if all commits are ticketed
- "In progress" populates from journal — user edits before posting
- Keep it scannable — one line per commit, no diff dumps

- **Expected output**: Formatted standup block displayed inline
- **Failure recovery**: If a section is empty, omit it rather than printing "None"

## Completion Criteria

- [ ] Target date resolved to absolute YYYY-MM-DD
- [ ] Journal entries located (or absence noted)
- [ ] Git activity gathered per repo
- [ ] Commits grouped by ticket and by Team workspace surface
- [ ] In-progress threads extracted from latest journal
- [ ] Standup block displayed inline, no files written

### Verification Commands

```bash
# Resolve yesterday's date
date -v-1d +%Y-%m-%d   # macOS
date -d yesterday +%Y-%m-%d   # Linux

# Confirm journal lookup pattern
ls memory/sessions/$(date -v-1d +%Y-%m-%d)-*.md 2>/dev/null

# Confirm git query pattern in a repo
git log --since="$(date -v-1d +%Y-%m-%d) 00:00" \
        --until="$(date -v-1d +%Y-%m-%d) 23:59" \
        --author="$(git config user.email)" \
        --pretty=format:"%h %s" --no-merges
```

## Usage Examples

### Default — Yesterday's Activity
```
/standup
```
Resolves to yesterday, reads matching journals + commits, prints standup block.

### Explicit Date
```
/standup 2026-05-04
```
Useful Monday morning when standup covers Friday's work.

### Recent Weekday
```
/standup friday
```
Resolves to the most recent past Friday.

## Integration Notes

- **`/journal`** writes the entries this skill reads — quality of standup depends on journal hygiene
- **`/recap`** reconstructs context for a new session; `/standup` produces a status update for others. Same input, different audience.
- Output is plain markdown — pastes cleanly into Slack, Jira, or any markdown surface

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "No journal entry for X" | Didn't run `/journal` that day | Use git activity alone; tighten journal habit |
| Same commit in two ticket buckets | Commit references multiple tickets | Prefer first match; note explicitly |
| Empty output | No commits + no journal | Show empty-day template; user fills manually |
| Wrong author filter | Different email per repo | Check `git config user.email` in each repo |
| Today's commits show up | Date boundary off by one | Verify timezone — `--since`/`--until` use local time |
