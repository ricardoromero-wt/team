---
name: ship
description: "End-to-end ship protocol — branch, verify, commit, push, PR. Use when starting or finishing work."
argument-hint: "[#issue] [description] — start new work; or no args to ship current branch"
---

# Ship — Start-to-Finish Delivery

## Purpose

Handle the full lifecycle from "starting work" to "PR is up." Detects which phase you're in: if you're on the base branch, it preps a new feature branch (mission prep). If you're on a feature branch with changes, it ships (verify, commit, push, PR).

> "Branch to PR is one pipeline. Skip a stage and you spend the savings later, with interest."

## Safety Constraints

### NEVER
- Force push (`--force`, `--force-with-lease`) — not even once
- Push without explicit user approval — show what will be pushed and wait
- Stage files with `git add -A` or `git add .` — stage specific files only
- Discard uncommitted changes — offer stash/commit/abort if the tree is dirty during prep
- Create a PR from main/dev/master — must be on a feature branch
- Amend commits without explicit user request

### ALWAYS
- Detect mode automatically (prep vs ship) based on current branch
- Confirm branch names with the user before creating
- Show the full commit diff before committing
- Require explicit user approval before pushing
- Use HEREDOC format for commit messages
- Offer session bookend skills (`/journal`, `ce:compound`) after shipping

## Known Failure Modes

| Failure | Cause | Recovery |
|---------|-------|----------|
| Dirty tree during prep | Uncommitted changes | Offer stash, commit, or abort — never silently discard |
| On protected branch during ship | Accidentally on main/dev/master | Switch to prep mode, suggest creating a feature branch |
| No changes to ship | Already committed or nothing changed | Check for unpushed commits; if none, report "nothing to ship" |
| `/verify` reports P1 | Quality gate blocks commit | Fix P1 issues first, then re-run `/ship` |
| Push rejected | Remote has new commits | Pull with rebase, resolve conflicts, then retry push |
| PR creation fails | No upstream branch or `gh` not authed | Push manually, create PR via web |
| Issue not found | Wrong number or private repo without auth | Report error, continue without issue context |

## Execution Protocol

### Step 1: Detect Mode

```bash
git branch --show-current
```

Detect the default branch:
```bash
git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'
```
Fallback order: `main`, `dev`, `master`.

**If current branch IS the base branch** → **Prep mode** (Steps 2-4)
**If current branch is NOT the base branch** → **Ship mode** (Steps 5-9)

- **Expected output**: Mode determined (prep or ship)
- **Failure recovery**: If not in a git repo, report and exit

### --- PREP MODE ---

### Step 2: Identify the Work

Parse `$ARGUMENTS` for task context:

- **Issue reference** (`#42` or `42`) — Fetch with `gh issue view 42 --json title,labels,body,number`
- **Freeform description** — Use as-is for branch naming
- **No arguments** — Ask the user what they're working on

- **Expected output**: Task title, optional issue number
- **Failure recovery**: If `gh issue view` fails, ask the user to describe the work manually

### Step 3: Pre-flight and Sync

Check tree is clean:
```bash
git status --short
```

If dirty: show files, offer stash/commit/abort, wait for user choice.

Sync base branch:
```bash
git pull origin {base_branch}
```

- **Expected output**: Clean tree, synced base
- **Failure recovery**: If pull fails, report and ask user how to proceed

### Step 4: Create Feature Branch

Derive branch name:
1. **Type prefix** — From issue labels or description: `bug` → `fix`, default → `feat`
2. **Slug** — From issue title or description, kebab-case, truncated to ~50 chars
3. **Format**: `{type}/{issue-number}-{slug}` (with issue) or `{type}/{slug}` (without)

Confirm with user, then:
```bash
git checkout -b {branch_name}
```

Optionally assign issue (if `gh` available and issue provided):
```bash
gh issue edit {number} --add-assignee $(gh api user --jq '.login')
```

Display prep summary and exit:
```
Branch:  feat/42-add-bookings-flow
Base:    main (synced)
Issue:   #42 — Add bookings flow (assigned)

Ready to build. Run /ship again when done to push and PR.
```

- **Expected output**: On new feature branch, ready to work
- **Failure recovery**: If branch exists, offer to checkout existing or pick a new name

### --- SHIP MODE ---

### Step 5: Ship Pre-flight

Verify shippable state:
```bash
git status --short
git log origin/{base}..HEAD --oneline 2>/dev/null
```

Three possible states:
- **Uncommitted changes exist** — proceed to verify and commit
- **Only unpushed commits** — skip to push (Step 7)
- **Nothing to ship** — report and exit

Detect issue number from branch name (e.g., `feat/42-add-auth` → `#42`).

- **Expected output**: Confirmed on feature branch with shippable changes
- **Failure recovery**: If no changes, report cleanly

### Step 6: Quality Gate

Run `/verify` (delegate — do not reimplement verification logic).

Interpret results:
- **P1 issues** → **Block**. Report findings, do not proceed to commit.
- **P2 issues** → **Warn**. Proceed but collect P2 items for PR body.
- **P3 issues** → **Pass**. Note in report.

If `/verify` was already run this session, acknowledge and proceed.

- **Expected output**: Verify verdict (pass/warn/block)
- **Failure recovery**: If `/verify` fails to run, warn user and ask whether to proceed without verification

### Step 7: Stage and Commit

Show changed files:
```bash
git diff --stat
```

Stage specific files (never `git add -A`):
```bash
git add {file1} {file2} ...
```

Craft a conventional commit message:
- **Subject**: Imperative mood, <72 chars
- **Body**: What and why. Include `Closes #{number}` if issue detected.
- **Trailer**: Co-Authored-By with agent name and model.

```bash
git commit -m "$(cat <<'EOF'
{subject}

{body}

{Closes #N if applicable}

Co-Authored-By: Team <ricardo.romero@willowtreeapps.com>
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

- **Expected output**: Clean commit with conventional message
- **Failure recovery**: If pre-commit hooks fail, fix issues and create a NEW commit (never amend)

### Step 8: Push and PR

Show what will be pushed and **require explicit user approval**:
```bash
git log origin/{base}..HEAD --oneline
```

Push:
```bash
git push -u origin {branch}
```

Create PR:
```bash
gh pr create --title "{title}" --body "$(cat <<'EOF'
## Summary
- {bullet points}

## Test Plan
- [ ] {verification steps}

## Notes
{Closes #N if applicable}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

If auto-merge is available:
```bash
gh pr merge {number} --squash --auto
```

- **Expected output**: PR created, URL returned, auto-merge enabled if available
- **Failure recovery**: If PR creation fails, output the body for manual creation

### Step 9: Ship Report and Bookends

Display summary:
```
Branch:   feat/42-add-bookings-flow
Commits:  3 (squash on merge)
PR:       https://github.com/org/repo/pull/99
Verify:   PASS (0 P1, 0 P2)

Run /journal to capture session state.
```

Offer (do not force) session continuity:
1. **`/journal`** — "Shipping is a natural session boundary. Capture working state?"
2. **`ce:compound`** — Only if the work involved non-obvious debugging: "That debugging session seems worth capturing."

- **Expected output**: Summary with PR URL, verify results, and session bookend offers
- **Failure recovery**: N/A — reporting step

## Completion Criteria

### Prep mode
- [ ] Working tree clean before branching
- [ ] Base branch detected and synced
- [ ] Feature branch created with confirmed name
- [ ] Issue assigned (if applicable)

### Ship mode
- [ ] Pre-flight confirmed: feature branch with shippable changes
- [ ] `/verify` delegated and verdict respected (P1 blocks)
- [ ] Changes staged file-by-file
- [ ] Commit created with conventional message and Co-Authored-By
- [ ] Push completed with explicit user approval
- [ ] PR created with summary and test plan
- [ ] Session bookend skills offered

### Verification Commands
```bash
git branch --show-current
git log origin/{branch}..HEAD --oneline
gh pr view --json url --jq '.url'
```

## Usage Examples

### Start new work from an issue
```
/ship #42
```

### Start work from description
```
/ship add bookings end-to-end flow
```

### Ship current work
```
/ship
```

## Integration Notes

- **`/verify`** — Core dependency. `/ship` delegates all quality checks to `/verify` and respects its verdicts.
- **`/journal`** — Offered after shipping. Shipping is a natural session boundary.
- **`/recap`** — Start of next session after shipping. Reconstructs context from journal.
- **`ce:compound`** — Offered when debugging was involved. Non-obvious solutions should be captured.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "Nothing to ship" | All changes already pushed | Check if PR already exists: `gh pr view` |
| Push rejected | Remote branch has new commits | Pull with rebase: `git pull --rebase origin {branch}` |
| PR creation fails | `gh` not authenticated | Run `gh auth login` and retry |
| Wrong mode detected | Expected prep but got ship (or vice versa) | `/ship` auto-detects from branch — checkout the right branch first |
| Commit blocked by hook | Pre-commit hook failure | Fix the issue, `git add`, create NEW commit (never amend) |
| Branch name collision | Branch already exists | Offer to checkout existing or pick a new name |
