#!/usr/bin/env bash
#
# backup.sh — copy the live ~/.claude/CLAUDE.md and ~/.agents/skills back into this repo.
#
# Usage:
#   ./backup.sh        # sync live → repo, then show what changed
#   ./backup.sh -n     # dry run: print what would change
#
# CLAUDE.md is always backed up. Skills come from ~/.agents/skills, the one place
# they're installed (~/.claude/skills only holds symlinks to them).
# Review `git diff` before committing: the live copy can be older than the repo.
#
# Portable bash 3.2+ (macOS system bash) and Linux (Omarchy/Arch).
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
AGENT_SKILLS_DIR="$HOME/.agents/skills"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

# Third-party skills installed alongside ours but not tracked in full here.
EXCLUDE=" cloudflare "

DRY_RUN=0
case "${1:-}" in
  -n | --dry-run) DRY_RUN=1 ;;
  "") ;;
  *)
    echo "Usage: $0 [-n|--dry-run]" >&2
    exit 2
    ;;
esac

run() {
  if ((DRY_RUN)); then
    echo "    [dry run] $*"
  else
    "$@"
  fi
}

# Compare with cksum rather than cmp/diff: Arch's base doesn't include diffutils.
same_file() {
  [[ -f $1 && -f $2 && "$(cksum <"$1")" == "$(cksum <"$2")" ]]
}

tree_sum() {
  (cd "$1" && find . -type f ! -name .DS_Store -exec cksum {} + | LC_ALL=C sort)
}

same_tree() {
  [[ -d $1 && -d $2 && "$(tree_sum "$1")" == "$(tree_sum "$2")" ]]
}

echo "CLAUDE.md: $CLAUDE_MD"
if [[ ! -f $CLAUDE_MD ]]; then
  echo "  $CLAUDE_MD not found" >&2
  exit 1
fi
if ! same_file "$CLAUDE_MD" "$REPO_DIR/CLAUDE.md"; then
  echo "  update  CLAUDE.md"
  run cp "$CLAUDE_MD" "$REPO_DIR/CLAUDE.md"
fi

echo "Skills: $AGENT_SKILLS_DIR"
for skill_md in "$AGENT_SKILLS_DIR"/*/SKILL.md; do
  [[ -f $skill_md ]] || continue
  skill_dir="$(dirname "$skill_md")"
  name="$(basename "$skill_dir")"
  case "$EXCLUDE" in *" $name "*) continue ;; esac

  dest="$REPO_DIR/$name"
  same_tree "$skill_dir" "$dest" && continue

  echo "  update  $name"
  run rm -rf "$dest"
  run mkdir -p "$dest"
  run cp -R "$skill_dir/." "$dest/"
  run find "$dest" -name .DS_Store -delete
done

git -C "$REPO_DIR" status --short
