#!/usr/bin/env zsh
#
# backup.zsh — copy the live ~/.claude/CLAUDE.md and skills back into this repo.
#
# Usage:
#   ./backup.zsh          # sync live → repo, then show what changed
#   ./backup.zsh -nv      # dry run (extra args pass straight to rsync)
#
# Override the sources with AGENT_SKILLS_DIR=/some/path or CLAUDE_MD=/some/file.
# Review `git diff` before committing: the live copy can be older than the repo.
#
set -euo pipefail

REPO_DIR="${0:A:h}"
SKILLS_DIR="${AGENT_SKILLS_DIR:-$HOME/.agents/skills}"
CLAUDE_MD="${CLAUDE_MD:-$HOME/.claude/CLAUDE.md}"

# Third-party skills installed alongside ours but not tracked in full here.
EXCLUDE=(cloudflare)

echo "CLAUDE.md: $CLAUDE_MD"
rsync -a "$@" "$CLAUDE_MD" "$REPO_DIR/CLAUDE.md"

echo "Skills: $SKILLS_DIR"
for skill_md in "$SKILLS_DIR"/*/SKILL.md(N); do
  skill_dir="${skill_md:h}"
  name="${skill_dir:t}"
  (( ${EXCLUDE[(Ie)$name]} )) && continue

  rsync -a --delete --exclude='.DS_Store' "$@" "$skill_dir/" "$REPO_DIR/$name/"
done

git -C "$REPO_DIR" status --short
