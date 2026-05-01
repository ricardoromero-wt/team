# Knowledge Freshness

## The Problem

Your training data has a cutoff date. Anything you "know" about external tools, library versions, security advisories, or best practices may be months stale. Stale claims presented with confidence are more dangerous than obvious gaps.

## Verification Protocol

Never assert version existence, deprecation status, or security advisory status as fact without live verification.

### Claims That Require Verification
- "Version X.Y.Z exists/doesn't exist"
- "This API/setting/tool is deprecated"
- "CVE-XXXX affects versions below Y"
- "The recommended approach is X"
- "This tool doesn't support feature Z"
- "This package/action is unmaintained"

### How to Verify
1. **Prefer deterministic tools over model knowledge.** Run the scanner, check the registry, query the API. Tool output is ground truth; training data is a hint.
2. If deterministic tools aren't available, use web_search or web_fetch.
3. If neither is available, state explicitly: "Based on training data (may be outdated)."
4. Cite the source of your verification in the finding.

### Confidence Levels
- **Verified**: Checked against live source or tool output this session
- **Training data**: Not verified — flag with ⚠️ and caveat
- **Uncertain**: Conflicting information — escalate to human review

## Domain-Specific Exposure

Team operates across two backend stacks (NestJS, Python services) and a React SPA. Highest-risk stale claims:

| Highest-Risk Stale Claims | Example |
|--------------------------|---------|
| NestJS version-specific APIs and decorators | "`@Injectable()` supports scope X in v10" — verify against the installed version's docs |
| Python framework APIs (FastAPI, Django, SQLAlchemy) | "FastAPI's `Depends()` behavior in v0.110+" — verify against `pyproject.toml`/`requirements` and live docs |
| React patterns and hook behavior | "React 19 introduces server components" — verify against React's release notes and the SPA's installed version |
| Package vulnerability and deprecation status | "`<package>` has a known CVE" — run `npm audit` / `pip-audit` for ground truth |
| GitHub Actions / CI tool capabilities and syntax | "`actions/checkout@v5` supports X" — check the action's marketplace page or release notes |
| Subagent / Claude harness features | "Claude Code supports skill X" — verify with `claude plugin list` and the current docs, since features evolve quickly |

When in doubt, run the scanner, check the registry, or fetch the docs. Never assert framework or package behavior from memory alone on protected work.
