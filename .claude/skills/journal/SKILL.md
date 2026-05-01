---
name: journal
description: Record session working state for continuity across conversations. Use at session boundaries or before context gets heavy.
---

# Journal — Session State Capture

## Purpose

Record working state at session boundaries so future sessions can reconstruct context without manual re-explanation. Fills the gap between ephemeral conversation context and permanent knowledge base entries.

> "Write it down before it fades. The session that ends without a journal is the session that has to be re-explained."

## Safety Constraints

### NEVER
- Include secrets, credentials, or sensitive data
- Overwrite an existing journal entry (each session gets its own file)
- Write journal entries for trivial sessions (quick questions, no meaningful state to capture)
- Block the user from ending their session to write a journal

### ALWAYS
- Auto-detect branch name and timestamp from the environment
- Auto-fill from conversation context where possible (minimize user effort)
- Verify the journal file was written correctly
- Keep entries concise — scannable in <10 seconds

## Known Failure Modes

| Failure | Cause | Recovery |
|---------|-------|----------|
| Directory doesn't exist | First journal entry or memory cleanup | Create `memory/sessions/` directory |
| Timestamp collision | Two sessions in the same minute | Append `-2` suffix to filename |
| Sparse entry | Session was short or exploratory | Still write it — even "explored X, decided not to pursue" is valuable |
| Stale context | Compaction happened mid-session | Gather what's available; note gaps in the entry |

## Execution Protocol

### Step 1: Gather Environment

Collect automatically:
1. **Timestamp**: Current date and time (`date +%Y-%m-%dT%H:%M`)
2. **Branch**: Current git branch (`git branch --show-current`)
3. **Filename**: `YYYY-MM-DD-HHMM.md` derived from timestamp

- **Expected output**: Timestamp, branch name, target filename
- **Failure recovery**: If not in a git repo, use `no-branch` as branch name

### Step 2: Synthesize Session State

From conversation context, gather:
1. **Summary**: 2-3 sentence overview of what happened this session
2. **Changes**: Files modified/created with one-line descriptions
3. **Decisions**: Key choices made and their rationale
4. **Next**: What to pick up next, open questions, blockers

Auto-fill where possible. Ask the user only for what can't be inferred.

- **Expected output**: Content for all four sections
- **Failure recovery**: If a section is empty (e.g., no files changed), note "None" rather than omitting

### Step 3: Write Journal Entry

Create the file at: `memory/sessions/{YYYY-MM-DD-HHMM}.md`

Format:
```yaml
---
date: {ISO timestamp}
branch: {branch-name}
tags: [session-journal, {relevant-tags}]
---
```

Followed by:
```markdown
## Summary
{2-3 sentences}

## Changes
- `path/to/file` — What changed
- `path/to/other` — What changed

## Decisions
- **Decision**: Rationale

## Next
- What to do next
- Open questions
- Blockers
```

- **Expected output**: Written file at the correct path
- **Failure recovery**: If directory doesn't exist, create it first. If write fails, output content for manual saving.

### Step 4: Verify Entry

1. Read back the created file to confirm correctness
2. Confirm YAML frontmatter is valid
3. Report success with file path

- **Expected output**: Confirmation message with file path
- **Failure recovery**: Fix formatting issues and re-write

### Step 5: Offer Memory Updates (Optional)

If stable patterns emerged during the session (not just working state), offer to update memory files. This is a suggestion, not automatic.

- **Expected output**: Suggestion to user, or skip if nothing qualifies
- **Failure recovery**: N/A — this step is advisory only

## Completion Criteria

- [ ] Timestamp and branch auto-detected
- [ ] All four sections populated (Summary, Changes, Decisions, Next)
- [ ] File written to `memory/sessions/` with valid YAML frontmatter
- [ ] File read back and verified

### Verification Commands
```bash
# Confirm file exists and is readable
ls memory/sessions/*.md | sort -r | head -1

# Confirm it's tagged
grep "session-journal" memory/sessions/*.md | tail -1
```

## Usage Examples

### End of Session
```
/journal
```
Auto-fills from conversation context. Asks user to confirm or adjust.

### Mid-Session Checkpoint
```
/journal
```
Same command — useful before a long divergence or when context is getting heavy.

### After Compaction
If context was compacted, `/journal` still works — it captures whatever state is available and notes the compaction.

## Integration Notes

- **`/recap`** reads journal entries to reconstruct context in new sessions — they're a matched pair
- **`ce:compound`** captures permanent solutions; `/journal` captures working state — they're complementary
- **Compact Instructions** in `.claude/rules/sessions.md` preserve the latest journal path so `/recap` works after compaction

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `memory/sessions/` not found | First journal entry | Create directory: `mkdir -p memory/sessions/` |
| Empty sections | Short or exploratory session | Write "None" — the entry still has value for continuity |
| Wrong branch recorded | Detached HEAD state | Note the commit SHA instead |
| Journal too verbose | Over-documenting | Keep Summary to 2-3 sentences, Changes to file list, Decisions to key choices only |
