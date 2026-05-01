# Session Continuity

## Three-Layer Persistence Model

| Layer | Location | Captures | Lifespan |
|-------|----------|----------|----------|
| **Session Journal** | `memory/sessions/` | Working state, decisions, progress | Weeks (rolling) |
| **Stable Memory** | `memory/` | Stable patterns, preferences | Indefinite |
| **Knowledge Base** | `docs/solutions/` | Solved problems, committed to repo | Permanent |

## Session Boundaries

Proactively offer to journal at natural session boundaries:
- **Task completion** — A significant task or multi-step workflow is finished
- **User signing off** — The user says goodbye, "that's all", or similar
- **Significant context shift** — About to switch to a completely different topic or codebase area
- **Pre-compaction** — When context is getting heavy and compaction is likely

Do NOT force journaling — offer it. If the session was trivial (a quick question, no state to capture), skip the offer.

## Recap Protocol

At the start of a new session when prior context would be helpful, suggest reconstructing working state from the session journal. This is especially useful after:
- Starting a new conversation
- Returning after a break
- Post-compaction when context was lost

## Compact Instructions

When compacting, preserve:
- Current task state and progress
- File changes made in this session (paths and what changed)
- Decisions made and their rationale
- Unresolved questions or blockers
- Path to the latest session journal (if one was written), so context can be reconstructed after compaction

Discard:
- Intermediate file read contents (can be re-read)
- Grep/glob search results (can be re-run)
- Verbose tool output that's already been synthesized
- Exploration that didn't lead to the current approach

**Post-compaction tip**: Reconstruct context from the session journal and git state before resuming work.
