# Knowledge Compounding

## When to Document
- A problem took more than 30 minutes to solve
- The solution was non-obvious or counter-intuitive
- A pattern emerged that will recur
- An integration required specific configuration that isn't well-documented
- A debugging session revealed something surprising

## What to Include
- **Problem**: What went wrong and how it manifested
- **Context**: Environment, versions, constraints
- **Investigation**: What you tried and why it did or didn't work
- **Solution**: The fix, with code if applicable
- **Lessons**: What to remember for next time

## Where to Store
Capture solutions into `docs/solutions/{category}/` where category is one of: `architecture`, `debugging`, `integration`, `tooling`, `performance`, `subagent-design`, `nestjs`, `python-react`.

## KB Entry Format

All entries follow this structure:

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

## After Documenting

After writing a KB entry, search for related entries by tag overlap (2+ shared tags). Suggest the top 5 related entries and offer to add reciprocal cross-links. Existing KB entries are protected artifacts — adding links requires user approval.

## Ideation Capture

Ideas need time to grow. Not every ideation session should end with "let's build it now." Document the thinking and move on. The plan plus a critique of that plan together form a complete ideation artifact.

### Persistence Rules
| Artifact Type | Location | Rationale |
|---------------|----------|-----------|
| Critique (plan review, spec review) | Ephemeral storage | Value is in the report output, not the tool |
| Architecture explorer, code map | `docs/playgrounds/` | Persistent — team reference value |
| Design artifact, concept map | `docs/playgrounds/` | Persistent — reusable for ongoing design decisions |
| Data explorer | Ephemeral or `docs/playgrounds/` | Depends on whether the query/schema is stable |
