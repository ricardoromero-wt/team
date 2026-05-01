#!/usr/bin/env bash
# Team — Launch your agent from anywhere.
#
# This function starts Claude Code with Team's full infrastructure
# (persona, rules, knowledge, skills, plugins) and adds your current
# working directory for code access.
#
# Setup:
#   Add this line to your ~/.bashrc or ~/.zshrc:
#
#     source "/Users/ricardoromero-mcfadden/Development/team/scripts/team.sh"
#
#   Then restart your terminal or run: source ~/.bashrc (or ~/.zshrc)
#
# Usage:
#   team                    # launch from current directory
#   team --model sonnet     # override model
#   team --resume           # resume last conversation
#
# Permission mode:
#   Uses --permission-mode auto by default. Auto mode runs a classifier
#   on every non-trivial action — safer than bypass, less interruptive
#   than default. If auto mode causes false positives, add specific allow
#   patterns to .claude/settings.local.json rather than disabling the
#   classifier entirely.

function team() {
    local target_dir
    target_dir="$(pwd)"
    (cd "/Users/ricardoromero-mcfadden/Development/team" && ENABLE_EXPERIMENTAL_MCP_CLI=true claude --permission-mode auto --add-dir "$target_dir" "$@")
}
