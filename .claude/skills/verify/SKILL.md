---
name: verify
description: "Pre-commit quality gate — run tests, check lint, verify the build. Use before committing."
---

# Verify — Pre-Commit Quality Gate

## Purpose

> "Don't tell me it works. Show me the test output."

Run tests, lint, and build checks before committing. Catch issues before they reach CI.

## Safety Constraints

### NEVER
- Skip failing tests to get a clean report
- Mark a stage as passed without running it

### ALWAYS
- Run all three stages before reporting done
- Be explicit about what couldn't be checked and why

## Execution

### Step 1: Run Tests

```bash
# Adapt to your project's test runner
npm test          # or: pnpm test / yarn test (Nest monorepo)
pytest            # Python services
```

- **P1**: Test failure — blocks commit
- **P3**: No test suite found — note and continue

### Step 2: Run Lint

```bash
# Adapt to your project's linter
npx eslint .                    # NestJS / React SPA
uv run ruff check .             # Python
```

- **P1**: Syntax errors — blocks commit
- **P2**: Style violations — warns, blocks merge
- No linter configured: report stage as unchecked

### Step 3: Verify Build

```bash
# Adapt to your project's build command
npm run build     # Nest monorepo
tsc --noEmit      # SPA type check (faster than full build)
```

- **P1**: Build failure — blocks commit
- No build step: skip and note

## Verdict

Report stage results (PASS / FAIL / UNCHECKED), total P1/P2 count, and a final line: `CLEAR TO COMMIT` or `COMMIT BLOCKED`.
