#!/usr/bin/env zsh
#
# update-skills.zsh — push this repo's skills to the live agent skills dir.
#
# Usage:
#   ./update-skills.zsh          # sync repo → ~/.agents/skills
#   ./update-skills.zsh -n       # dry run (extra args pass straight to rsync)
#
# Override the destination with AGENT_SKILLS_DIR=/some/path ./update-skills.zsh
#
set -euo pipefail

# Resolve the repo root from this script's own location, so it works
# regardless of username or where the repo is checked out.
REPO_DIR="${0:A:h}"
DEST_DIR="${AGENT_SKILLS_DIR:-$HOME/.agents/skills}"

mkdir -p "$DEST_DIR"

echo "Syncing skills: $REPO_DIR/ → $DEST_DIR/"
rsync -av \
  --exclude='.git/' \
  --exclude='.DS_Store' \
  --exclude='.claude/' \
  "$@" \
  "$REPO_DIR/" "$DEST_DIR/"
