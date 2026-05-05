---
name: open-pr
description: Open a draft PR on fuelix/core on behalf of ricardoromero-wt, using the repo PR template and Jira ticket context
version: 1.1.0
triggers:
  - /open-pr
requires:
  - gh CLI authenticated as ricardoromero-wt
  - Must be run from /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/core
  - Active branch must not be main
  - Active branch must already be pushed to origin (the agent never runs `git push` — see `.claude/rules/safety.md` → Pushing). If not pushed, the skill stops and asks the user to push.
---

# open-pr — Draft PR Creator for fuelix/core

## Purpose

Open a draft pull request on `fuelix/core` targeting `main`, using:
- The repo's `.github/pull_request_template.md` as the body structure
- Jira ticket context auto-extracted from the branch name
- A summary of what changed, derived from the git diff and commit log

PRs are always opened as **drafts**. The user marks them ready for review manually.

---

## Usage

```
/open-pr
/open-pr --title "Custom PR title override"
```

No arguments required — the skill derives everything from the current branch and Jira.

---

## Execution Protocol

### Step 1 — Preflight checks

Run these in the Fuel/core repo directory:

```bash
# 1. Confirm we're in the right repo
cd /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/core
git remote get-url origin
# Expected: git@github.com:fuelix/core.git

# 2. Confirm not on main
git branch --show-current
# Must NOT be "main"

# 3. Confirm gh is using ricardoromero-wt
GITHUB_TOKEN="" gh api user --jq .login 2>/dev/null
# Expected: ricardoromero-wt
```

**If gh is not authenticated as ricardoromero-wt:**
```bash
# Switch to correct account (if already added)
GITHUB_TOKEN="" gh auth switch --user ricardoromero-wt

# If ricardoromero-wt is not yet added, instruct the user:
# ! GITHUB_TOKEN="" gh auth login
# Then select ricardoromero-wt and authenticate via browser
```

**CRITICAL:** The `GITHUB_TOKEN` env var overrides all keyring accounts. Always prefix `gh` commands with `GITHUB_TOKEN=""` to bypass it and use the keyring.

**Failure recovery:** If preflight fails, stop and report the specific check that failed before proceeding.

---

### Step 2 — Read current state

```bash
cd /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/core

# Current branch
BRANCH=$(git branch --show-current)

# Commits on this branch not yet in main
git log main..HEAD --oneline

# Changed files summary
git diff main..HEAD --stat

# Check if branch is pushed to origin
git status -sb
```

Save: branch name, commit list, file change summary.

---

### Step 3 — Extract Jira ticket

Parse the ticket ID from the branch name using this pattern: `^([A-Z]+-[0-9]+)`

Examples:
- `AQ-531-generate-vconstranscripts` → `AQ-531`
- `AC-671-FE-Integration-for-File-Upload` → `AC-671`
- `feature/AQ-100-new-thing` → `AQ-100`

If no ticket is found, the `Closes:` field will be left blank and the user will be notified.

---

### Step 4 — Fetch Jira ticket details

Use the Atlassian MCP tool to fetch the ticket:

```
getJiraIssue(cloudId="fuelix.atlassian.net", issueIdOrKey="<ticket-id>", responseContentFormat="markdown")
```

Extract:
- **summary** → used to build the default PR title
- **description** → used to inform the PR body summary (do not paste verbatim; synthesize)
- **issueType** → helps classify the PR as Feature / Fix / Enhancement

If the Jira fetch fails, proceed without it and note the gap.

---

### Step 5 — Build the PR title

Format: `<TICKET-ID>: <concise description>`

Rules:
- If `--title` was provided, use that verbatim
- Otherwise: derive from the Jira summary, cleaned up and shortened to ~70 chars
- Examples:
  - `AQ-531: Generate 5,000 VCON transcripts for AQM evaluation`
  - `AC-671: FE integration for non-image file upload in Agent Assist`

---

### Step 6 — Build the PR body

Use the template at `.github/pull_request_template.md` as the structure. Fill it in:

```markdown
## <Feature|Fix|Enhancement>: <title>

<2–4 sentence summary of what was changed and why. Be specific — mention
the files/modules touched, what problem is solved, and any key decisions.
Do not paste the Jira description verbatim; synthesize from the diff.>

Closes: https://fuelix.atlassian.net/browse/<TICKET-ID>

## Demos/Screenshots

<!-- To be added by the author before marking ready for review -->

## Checklist

- [ ] Acceptance criteria are met
- [ ] New tests added for changed/new functionality
- [ ] README updated (if applicable)
- [ ] Jira/Confluence updated (if applicable)
```

**Classify the PR type** (Feature / Fix / Enhancement) based on:
- Jira issue type field
- Nature of the diff (new files = likely Feature, bug-related = Fix, refactor/improvement = Enhancement)

---

### Step 7 — Verify the branch is on origin (do **not** push)

The agent **never** runs `git push` (per `.claude/rules/safety.md` → **Pushing**). Confirm the branch exists on origin and is in sync; if not, stop and ask the user to push.

```bash
cd /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/core
BRANCH=$(git branch --show-current)

# Refresh the remote-tracking ref (read-only)
git fetch origin "$BRANCH" --quiet 2>/dev/null

# Does the remote branch exist?
if ! git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null; then
  echo "BRANCH_NOT_ON_ORIGIN"
  exit 0
fi

# Are local and remote in sync?
AHEAD=$(git rev-list --count "origin/$BRANCH..HEAD")
BEHIND=$(git rev-list --count "HEAD..origin/$BRANCH")
echo "ahead=$AHEAD behind=$BEHIND"
```

**Failure handling — do not push, ask the user instead:**

- `BRANCH_NOT_ON_ORIGIN` → tell the user:
  > Branch `<name>` is not on origin yet. Per the safety rules I never run `git push`. Please run `git push` (upstream is pre-configured if you used the standard branch-creation flow in `safety.md` → Branching). Once pushed, reply "pushed" and I'll continue with Step 8.
- `ahead > 0` → unpushed commits; tell the user:
  > Branch `<name>` has `<N>` unpushed commit(s). Please run `git push`, then I'll continue.
- `behind > 0` → local is behind origin; tell the user:
  > Local is behind `origin/<name>` by `<N>` commit(s). Pull or rebase first, then re-invoke `/open-pr`.

Only proceed to Step 8 when both `ahead=0` and `behind=0` and the remote branch exists.

---

### Step 8 — Create the draft PR

```bash
cd /Users/ricardoromero-mcfadden/Documents/ClientProjects/SE/Fuel/core

GITHUB_TOKEN="" gh pr create \
  --draft \
  --base main \
  --title "<PR title from Step 5>" \
  --body "$(cat <<'PRBODY'
<PR body from Step 6>
PRBODY
)"
```

Capture the output — it will contain the PR URL.

---

### Step 9 — Confirm and report

Report back with:
- PR URL
- Title
- Jira ticket linked
- Branch → base
- Number of commits and files changed

Example:
```
Draft PR opened:
  URL:     https://github.com/fuelix/core/pull/1234
  Title:   AQ-531: Generate 5,000 VCON transcripts for AQM evaluation
  Jira:    https://fuelix.atlassian.net/browse/AQ-531
  Branch:  AQ-531-generate-vconstranscripts → main
  Commits: 3 commits, 12 files changed
```

---

### Step 10 — Capture ticket recap

Invoke the `/ticket-recap` skill (best-effort) to write a one-page recap of the work to `~/Development/team/docs/<project>/ticket-recaps/<TICKET-ID>.md`. The recap captures scope, surface area, decisions, contracts, and gotchas — the synthesis that won't survive in git or Jira on its own.

- This step runs **after** the PR is open (so the PR URL and body are part of the recap input).
- If the recap step fails for any reason (Jira down, no ticket ID, etc.), do **not** roll back the PR. Note the failure in the final report and let the user run `/ticket-recap` manually later.
- Include the recap path in the final report:

```
Draft PR opened:
  URL:     https://github.com/fuelix/core/pull/1234
  ...
  Recap:   docs/core/ticket-recaps/AQ-531.md
```

---

## Safety Constraints

### NEVER
- Run `git push` for any reason — even `-u` on a brand-new branch (per `.claude/rules/safety.md` → **Pushing**). The user runs all pushes.
- Target `main` directly with the PR
- Open a non-draft PR without explicit user instruction
- Use the `iamricardo` gh account

### ALWAYS
- Prefix every `gh` command with `GITHUB_TOKEN=""` to bypass the invalid env var
- Confirm the active gh account is `ricardoromero-wt` before creating the PR
- Open PRs as draft
- Verify the branch exists on origin AND is in sync with `HEAD` (`ahead=0 behind=0`) before calling `gh pr create`

---

## Known Failure Modes

| Failure | Cause | Recovery |
|---------|-------|----------|
| `gh` uses wrong account | `GITHUB_TOKEN` env var overriding keyring | Prefix all `gh` commands with `GITHUB_TOKEN=""` |
| `ricardoromero-wt` not in keyring | Account never added to gh | Ask user to run `! GITHUB_TOKEN="" gh auth login` |
| Branch not on origin | User hasn't pushed yet | Ask user to run `git push` (upstream is pre-configured per `safety.md` → Branching). **Do not push.** |
| Branch ahead of origin | Local has unpushed commits | Ask user to run `git push`, then continue |
| Branch behind origin | Local missing upstream commits | Ask user to pull/rebase, then re-invoke |
| Jira fetch fails | Auth/network issue | Proceed without Jira context; leave `Closes:` blank |
| No ticket in branch name | Branch named without ticket prefix | Note it; leave `Closes:` blank, ask user if they want to add one |
| PR already exists for branch | Duplicate creation attempt | Run `GITHUB_TOKEN="" gh pr view` and report the existing PR URL |

---

## Integration Notes

- Pairs well with `/verify` — run verify before `/open-pr` to ensure CI will pass
- The draft PR body is the starting point; the user is expected to add screenshots/recordings before marking ready for review
- Jira ticket link in `Closes:` does not auto-close the Jira issue — it's informational only
