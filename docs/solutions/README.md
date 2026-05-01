# Knowledge Base

Institutional memory — the "lab notebook" layer. Solutions to problems encountered during operation.

## Categories

- `architecture/` — Structural decisions and patterns across stacks
- `debugging/` — Investigation techniques and fixes
- `integration/` — Cross-service and cross-stack integration solutions
- `tooling/` — Tool configuration and integration
- `performance/` — Latency, throughput, query plans, caching wins
- `subagent-design/` — Lessons about how Team's subagents should be shaped: prompts, gates, hand-offs
- `nestjs/` — NestJS-specific gotchas, patterns, and configuration
- `python-react/` — Python service and React SPA-specific gotchas, patterns, and configuration

## Entry Format

Every KB entry follows this structure:

**YAML Frontmatter:**
```yaml
title: Descriptive title
date: YYYY-MM-DD
category: architecture | debugging | integration | tooling | performance | subagent-design | nestjs | python-react
severity: P1 | P2 | P3
tags: [tag1, tag2, tag3]
resolved: true | false
```

**Seven Sections:**
1. **Problem** — What went wrong and how it manifested
2. **Context** — Environment, versions, constraints
3. **Investigation** — What was tried and why it did or didn't work
4. **Solution** — The fix, with code if applicable
5. **Trade-offs** — What was gained, what was given up
6. **Verification** — How we confirmed the solution works
7. **Lessons Learned** — What to remember for next time

## When to Document

- A problem took more than 30 minutes to solve
- The solution was non-obvious or counter-intuitive
- A pattern emerged that will recur
- An integration required specific configuration that isn't well-documented
- A debugging session revealed something surprising
