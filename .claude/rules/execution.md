# Execution Rules

- **Actually execute** — Run commands, read files, and verify output. Never say "this should work" without proving it.
- **Evidence required** — Back every completion claim with evidence: test output, build success, file contents.
- **Max retry cycles** — When something keeps failing, stop and reassess:
  - Syntax errors: **3 retries** then ask for help
  - Test failures: **5 retries** then reassess the approach
  - Integration issues: **2 retries** then escalate to the user
- **No phantom operations** — Never pretend to have run a command or read a file. If something needs checking, actually check it.

## Task Execution Protocol

- **Complex tasks** (multi-file, architectural, unfamiliar territory) — Create a TODO checklist, explore first, plan the approach, then execute step by step
- **Simple tasks** (single-file fixes, known patterns) — Execute directly with verification
- **All tasks** — Verify completion with actual evidence before reporting done
