---
name: recap
description: Warm-start a session by reconstructing context from journals and git state. Use at the start of new sessions.
argument-hint: "[N] — read last N journal entries (default: 1)"
---

# Recap — Session Context Reconstruction

## Purpose

Warm-start a new session by synthesizing context from session journals, git history, and repo state. Eliminates the manual "where were we?" dance at the start of every conversation.

> "Read the journal before guessing. Past Team already wrote down what current Team needs to know."

## Safety Constraints

### NEVER
- Modify any files (this is a read-only operation)
- Make assumptions about what the user wants to do next — present the state, let them decide
- Skip git status checks (uncommitted work is critical context)
- Display sensitive data from journal entries without context

### ALWAYS
- Read the most recent journal entry by default
- Include current git state (branch, status, recent commits)
- Present a structured, scannable briefing
- Note any gaps or inconsistencies (e.g., journal mentions branch X but we're on branch Y)

## Known Failure Modes

| Failure | Cause | Recovery |
|---------|-------|----------|
| No journal entries found | First session or journals cleaned up | Fall back to git history only |
| Journal references stale branch | Branch was merged or deleted | Note the discrepancy, show current state |
| Large gap between sessions | Days/weeks since last journal | Read last 2-3 journals for broader context |
| Post-compaction resume | Context was auto-compacted | Journal path in compaction instructions helps locate last entry |
| Wrong "most recent" journal | `ls -t` sorts by mtime, not filename | Sort by filename (`sort -r`) since names are `YYYY-MM-DD-HHMM.md` |

## Execution Protocol

### Step 1: Locate Journal Entries

Search for journal files in `memory/sessions/`, sorted by filename (chronological):
```bash
ls memory/sessions/*.md | sort -r
```

Select entries to read:
- **Default**: Most recent 1 entry
- **If user specifies**: Last N entries (e.g., `/recap 3`)
- **If gap > 3 days**: Automatically read last 2 entries for continuity

- **Expected output**: List of journal files to read
- **Failure recovery**: If no journals exist, skip to Step 3 (git-only briefing)

### Step 2: Read Journal Entries

Read selected journal entry/entries. Extract:
- Summary of what happened
- Key decisions made
- Files that were changed
- Next steps / open questions / blockers

- **Expected output**: Parsed journal content
- **Failure recovery**: If journal is malformed, display raw content and note the issue

### Step 3: Gather Git State

Run in parallel:
1. `git branch --show-current` — Current branch
2. `git status --short` — Uncommitted changes (never use -uall)
3. `git log --oneline -10` — Recent commits

- **Expected output**: Branch name, uncommitted changes, recent commit list
- **Failure recovery**: If not in a git repo, skip git state section

### Step 4: Detect Discrepancies

Check for inconsistencies between journal and current state:
- Branch mismatch (journal says X, currently on Y)
- Files mentioned in journal "Next" that have since been modified
- Commits made after the journal entry

- **Expected output**: List of discrepancies (if any)
- **Failure recovery**: N/A — discrepancies are informational

### Step 5: Synthesize Briefing

Compose and display a structured briefing. Do NOT write this to a file — display it directly in the conversation.

Format:
```markdown
## Session Briefing

### Last Session ({date}, branch: {branch})
{Summary from journal}
**Next steps**: {Next from journal}

### Recent Commits
- {hash} {message}
- {hash} {message}
- ...

### Current State
- **Branch**: {current branch}
- **Uncommitted**: {list or "clean"}
- **Discrepancies**: {any mismatches between journal and current state}

### Open Questions
{From journal, if any}
```

- **Expected output**: Formatted briefing displayed to user
- **Failure recovery**: If any section can't be populated, note "unavailable" rather than omitting

## Completion Criteria

- [ ] Journal entries located and read (or noted as absent)
- [ ] Git state gathered (branch, status, recent commits)
- [ ] Discrepancies between journal and current state identified
- [ ] Structured briefing displayed to user
- [ ] No files modified

### Verification Commands
```bash
# Confirm journals are readable (sorted by filename, not mtime)
ls memory/sessions/*.md | sort -r | head -5

# Confirm git state is accessible
git status --short && git log --oneline -5
```

## Usage Examples

### Start of New Session
```
/recap
```
Reads the most recent journal entry + git state. Displays briefing.

### Deep Context Recovery
```
/recap 3
```
Reads the last 3 journal entries for broader context (e.g., after a long break).

### After Compaction
```
/recap
```
Same command — the journal persists outside the conversation context, so it works even after compaction wipes the conversation.

## Integration Notes

- **`/journal`** writes the entries that `/recap` reads — they're a matched pair
- **Compact Instructions** in `.claude/rules/sessions.md` preserve the latest journal path so `/recap` can find it
- `/recap` is read-only — it never modifies journals, git state, or any files

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "No journal entries found" | First session or directory missing | Use `/journal` at the end of this session to start the chain |
| Stale briefing | Journal is from days ago | Use `/recap 3` for broader context, or note the gap |
| Branch mismatch | Switched branches since last journal | Informational — recap notes the discrepancy |
| Missing git state | Not in a git repo | Recap works without git, just shows journal content |
