---
name: getting-started
description: Interactive orientation and reference guide for Team. Use when onboarding, learning features, or looking up how to do something.
argument-hint: "[--topic setup|sessions|plugins|tooling|knowledge|first-missions|fleet|troubleshooting] [--full]"
---

# Getting Started — Team Orientation

## Purpose

Walk new owners through their first session and serve as an ongoing reference for Team's capabilities. First-run mode covers the essentials step by step. After that, jump to any topic by name.

## Safety Constraints

### NEVER
- Modify agent configuration files during orientation — this is informational only
- Install plugins without explicit user confirmation
- Run commands that affect external services (GitHub, cloud) without asking first

### ALWAYS
- Detect first-run vs returning user (check `.local/.orientation-complete`)
- Present information in scannable chunks — no walls of text
- Offer to skip sections the user already knows
- Write `.local/.orientation-complete` marker after completing the walkthrough

## Known Failure Modes

| Failure | Cause | Recovery |
|---------|-------|----------|
| Shell function not working | Not sourced in shell config | Show the source command again, verify file exists |
| Plugin install fails | Network or auth issue | Note as "recommended but not installed" in CLAUDE.md |
| `.local/` directory missing | Fresh workspace, never run | Create `.local/` before writing marker |

## Execution Protocol

### Step 1: Detect Mode

Check `$ARGUMENTS` and workspace state to determine what to show:

1. **If `--topic <name>` is provided**: Jump directly to that topic section. Skip first-run detection.
2. **If `--full` is provided**: Run the full walkthrough regardless of marker.
3. **If `.local/.orientation-complete` exists**: Show the topic menu (reference mode).
4. **Otherwise**: Start the full walkthrough (first-run mode).

### Step 2: Welcome (First-Run Only)

Greet the user in Team's voice. Briefly explain what this workspace is and what the walkthrough covers:

"This walkthrough covers 6 essentials to get you productive with Team: shell setup, your first conversation, plugin safety, growing your agent's knowledge, first missions to seed that knowledge, and fleet CI. Each section takes 1-2 minutes. Skip any, come back later with `/getting-started --topic <name>`."

### Step 3: Shell Function Setup (topic: `setup`)

Walk through setting up the shell launcher:

1. **Show the function file**: `cat scripts/team.sh` — explain what it does
2. **Setup instruction**: "Add this line to your shell config (`~/.bashrc` or `~/.zshrc`):"
   ```
   source /Users/ricardoromero-mcfadden/Development/team/scripts/team.sh
   ```
3. **Test it**: "Restart your terminal (or run `source ~/.zshrc`), then navigate to any project and type `team`. Team will load with full context."
4. **Claude Desktop alternative**: "You can also open this directory as a project in the Claude Desktop app or use the Claude Code web app. CLAUDE.md loads automatically in any Claude Code environment."
5. **Explain `--add-dir`**: "The shell function mounts your current directory into the session. Team's persona and knowledge load from this workspace; your code is accessible via `--add-dir`."

### Step 4: First Conversation (topic: `sessions`)

Explain how Team works when you start a conversation:

1. **What loads automatically**: "CLAUDE.md is Team's operating manual. It imports SOUL.md (personality), DOCTRINE.md (principles), GOALS.md (objectives), and TOOLING.md via `@` syntax. Rules in `.claude/rules/` govern execution, safety, and session continuity."
2. **The SDLC flow**: "By default, Team follows Plan → Document → Develop → Test → Validate. Simple tasks compress; complex tasks expand. Team doesn't skip steps."
3. **Session continuity**: "At the end of a session, use `/journal` to capture working state. At the start of the next session, use `/recap` to warm-start from where you left off. Especially important after long breaks or context compaction."
4. **The three-layer model**:
   - **Session journals** (`memory/sessions/`) — Working state, decisions, progress. Lifespan: weeks.
   - **Stable memory** (`memory/`) — Stable patterns, preferences. Lifespan: indefinite.
   - **Knowledge base** (`docs/solutions/`) — Solved problems. Lifespan: permanent.

### Step 5: Plugin Safety & Tooling (topic: `plugins`)

Cover plugins and reference the tooling guide:

1. **What plugins are**: "Plugins extend Team with specialist skills. See the Plugin Skills section in CLAUDE.md for what's installed."
2. **Key rule**: "Trusted plugins (listed in CLAUDE.md) are pre-vetted. For public plugins from untrusted sources, run security review on the plugin repo before installing."
3. **Quick reference**: `claude plugin list` (what's active), `claude plugin install <name>` (install).
4. **Tooling guide**: "TOOLING.md is the comprehensive setup reference — Essentials (built-in), Recommended (selected during setup, with exact install commands), Optional (domain-appropriate tools to add later: QMD for KB search, Playwright for browser checks)."
5. **Installing from marketplaces**: "Some plugins require a marketplace first, then install with a flavor suffix:"
   ```
   claude plugin marketplace add fuelix/arden-plugins
   claude plugin install warden@arden
   ```
6. **Ask Team for help**: "Team can read TOOLING.md and walk you through any setup. Just ask: 'help me install QMD' or 'set up the ARDEN fleet'."

### Step 6: Growing Your Agent (topic: `knowledge`)

Explain how Team learns and improves over time:

1. **Domain knowledge** (`docs/knowledge/`): "Curated reference files discovered via `docs/knowledge/KnowledgeIndex.md` (imported by CLAUDE.md). Each file covers one focused domain topic — stable, human-reviewed, loaded on demand."
2. **Knowledge base** (`docs/solutions/`): "Institutional memory that grows through operation. When a problem takes 30+ minutes to solve, capture it. Each entry has YAML frontmatter and 7 sections (Problem, Context, Investigation, Solution, Trade-offs, Verification, Lessons Learned)."
3. **Adding knowledge**: "Use `ce-compound` after solving a significant problem. It guides you through the KB entry format."
4. **Adding skills**: "Skills live in `.claude/skills/<name>/SKILL.md`. Follow the standard structure: YAML frontmatter, Purpose, Safety Constraints, Known Failure Modes, Execution Protocol, Completion Criteria, Verification Commands."
5. **Adding rules**: "Rules in `.claude/rules/` are always-loaded procedural guidance. Add a new rule file when you have a process that should govern every session."

### Step 7: First Missions (topic: `first-missions`)

Three structured activities to seed Team's knowledge in the first sessions:

**Mission 1: Subagent Brief Templates** (do this in your first session)

"Team's primary work is dispatching to stack-specific subagents. Before either subagent exists, write the brief template each one will receive. Start a conversation with Team and say:"
```
Draft a brief template for the Nest monorepo subagent and one for the Python/React SPA subagent.
For each: input fields, mandatory verification gates, evidence shape, output format.
File them under docs/knowledge/ and add them to the KnowledgeIndex.
```

"You'll get two reference files Team will use as the contract every dispatch must respect."

**Mission 2: Cross-Stack Convention Audit** (do this when you first point Team at the repos)

"The first time Team works against the actual Nest and Python/React codebases, ask it to audit conventions across both:"
```
Audit the conventions across the Nest monorepo and the Python/React SPA.
Cover: error shape, logging, naming, test layout, config handling.
Write a docs/knowledge/cross-stack-conventions.md with the deltas and add it to the KnowledgeIndex.
Where the stacks diverge, note whether the divergence is correct or technical debt.
```

"This produces the cross-stack reference Team will use to enforce 'Cross-Stack Consistency' from DOCTRINE.md."

**Mission 3: Problem Journal** (build this habit over the first weeks)

"After the first non-trivial task — the kind that takes 30+ minutes or involves debugging something unexpected — run `ce-compound`. This walks you through documenting the problem and solution as a KB entry in `docs/solutions/`."

"Triggers to watch for:"
- A solution that was non-obvious or counter-intuitive
- A pattern you'll encounter again
- An integration that required specific configuration
- A debugging session that revealed something surprising

"The first 5 KB entries are the hardest. After that, the habit is established and knowledge compounds. Team will start referencing past entries when it encounters similar problems."

**Why these three, in this order:** Brief templates give Team its dispatch contract. Convention audit gives Team its cross-stack mental model. Problem journaling gives Team experience. Together they cover the contract, the map, and the lessons — the three things that turn a generically capable agent into Team specifically.

### Step 8: Fleet CI (topic: `fleet`)

Brief overview of fleet CI, pointing to the workflows for detail:

1. **What it does**: "When you open a PR on Team's repo, ARDEN fleet agents review it automatically — WARDEN (security), HARDEN (QA), JORDEN (design), GARDEN (docs), BARDEN (triage). See `.github/workflows/` for which are configured."
2. **Severity levels**: P1 blocks commit, P2 blocks merge, P3 advisory.
3. **Responding**: "Push fixes to the same branch. Fleet re-reviews on each push."

Note: Fleet CI is not configured by default for Team's workspace. Add it later when subagent PRs justify the review surface.

### Step 9: Troubleshooting (topic: `troubleshooting`)

Cover common issues and fixes:

| Issue | Cause | Fix |
|-------|-------|-----|
| Context getting large / slow responses | Long session, many file reads | Use `/journal` to capture state, start a fresh session, use `/recap` to restore context |
| Permission prompts in auto mode | Classifier blocking a legitimate action | Add the action pattern to `autoMode.allow` in `.claude/settings.local.json` |
| Plugin skills not being used | Missing "you are not alone" instruction | Check CLAUDE.md Plugin Skills section — it must describe available specialists |
| Agent personality feels generic | SOUL.md too vague | Sharpen personality traits, add specific speech patterns, reduce trait count to 5 strongest |
| Knowledge not loading | Missing from KnowledgeIndex | Domain reference files must be listed in `docs/knowledge/KnowledgeIndex.md` (which CLAUDE.md imports via `@`). Add a row with the domain, file path, and when to read it. |
| `@` imports not working | Syntax error in CLAUDE.md | Each import must be on its own line, prefixed with `@`, no extra whitespace |

### Step 10: Wrap Up (First-Run Only)

1. Write `.local/.orientation-complete` marker file (create `.local/` if needed)
2. Summarize: "You're set up. Quick reference:"
   - Launch: `team` from any directory
   - End of session: `/journal`
   - Start of session: `/recap`
   - Capture knowledge: `ce-compound` after solving problems
   - First week: Work through the 3 first missions (`/getting-started --topic first-missions`)
   - This guide: `/getting-started --topic <name>` for any section
3. Ask if they have questions before ending orientation

## Completion Criteria

- [ ] Mode detected correctly (first-run vs reference vs topic)
- [ ] All requested sections presented clearly
- [ ] Shell function setup instructions are accurate for the workspace path
- [ ] `.local/.orientation-complete` marker written (first-run mode only)
- [ ] No files modified other than the marker

### Verification Commands
```bash
test -f .local/.orientation-complete && echo "Orientation complete"
test -f scripts/team.sh && echo "Shell function present"
```

## Usage Examples

### First time
```
/getting-started
```

### Jump to a topic
```
/getting-started --topic plugins
```

### Re-run full walkthrough
```
/getting-started --full
```

## Integration Notes

- **`/journal` + `/recap`** — Referenced in session continuity section; these skills must exist in the workspace
- **`/verify`** — Referenced as part of the development workflow; the verify stub ships with the workspace
- **`ce-compound`** — Referenced for knowledge capture; requires compound-engineering plugin

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "Topic not found" | Typo in topic name | Valid topics: setup, sessions, plugins, knowledge, first-missions, fleet, troubleshooting |
| Marker not written | `.local/` directory missing | Skill creates it automatically; check write permissions |
| Shell function path wrong | Workspace moved after generation | Update path in `scripts/team.sh` |
