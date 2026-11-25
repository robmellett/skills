#!/usr/bin/env bash
#
# install.sh — install this repo's skills and CLAUDE.md into the live setup.
#
#   <skill>/  → ~/.agents/skills/<skill>/   (every top-level dir with a SKILL.md)
#             → ~/.claude/skills/<skill> -> ../../.agents/skills/<skill>
#   CLAUDE.md → ~/.claude/CLAUDE.md
#
# Anything about to be replaced that differs from the repo — the live CLAUDE.md,
# a live skill dir, or a real dir sitting where a Claude symlink belongs — is
# moved into ~/.agents/backups/<timestamp>/ first, so nothing is lost.
#
# Usage:
#   ./install.sh        # install
#   ./install.sh -n     # dry run: print what would change
#
# Portable bash 3.2+ (macOS system bash) and Linux (Omarchy/Arch).
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
AGENT_SKILLS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
BACKUP_DIR="$HOME/.agents/backups/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
BACKED_UP=0
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

# Move <path> into the backup dir as <name>.
backup() {
  local src=$1 dest="$BACKUP_DIR/$2"
  echo "  backup  $src → $dest"
  BACKED_UP=1
  run mkdir -p "$(dirname "$dest")"
  run mv "$src" "$dest"
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

install_claude_md() {
  local src="$REPO_DIR/CLAUDE.md" dest="$CLAUDE_DIR/CLAUDE.md"

  if [[ -e $dest || -L $dest ]]; then
    if same_file "$src" "$dest"; then
      echo "  unchanged  $dest"
      return
    fi
    backup "$dest" "CLAUDE.md"
  fi

  echo "  install $dest"
  run cp "$src" "$dest"
}

install_skill() {
  local name=$1 src="$REPO_DIR/$1" dest="$AGENT_SKILLS_DIR/$1"

  if [[ -e $dest || -L $dest ]]; then
    if same_tree "$src" "$dest"; then
      return
    fi
    backup "$dest" "agents-skills/$name"
  fi

  echo "  install $dest"
  run mkdir -p "$dest"
  run cp -R "$src/." "$dest/"
  run find "$dest" -name .DS_Store -delete
}

link_skill() {
  local name=$1 link="$CLAUDE_SKILLS_DIR/$1" target="../../.agents/skills/$1"

  if [[ -L $link ]]; then
    [[ "$(readlink "$link")" == "$target" ]] && return
    run rm "$link"
  elif [[ -e $link ]]; then
    # A real dir here would shadow the agents copy; Claude must use the symlink.
    backup "$link" "claude-skills/$name"
  fi

  echo "  link    $link -> $target"
  run ln -s "$target" "$link"
}

# Remove Claude symlinks into ~/.agents/skills whose skill no longer exists.
prune_dangling_links() {
  local link
  for link in "$CLAUDE_SKILLS_DIR"/*; do
    [[ -L $link && ! -e $link ]] || continue
    case "$(readlink "$link")" in
      *.agents/skills/*)
        echo "  prune   $link (dangling)"
        run rm "$link"
        ;;
    esac
  done
}

if [[ "$(cd "$AGENT_SKILLS_DIR" 2>/dev/null && pwd -P)" == "$REPO_DIR" ]]; then
  echo "$AGENT_SKILLS_DIR resolves to this repo; refusing to install over it." >&2
  exit 1
fi

run mkdir -p "$AGENT_SKILLS_DIR" "$CLAUDE_SKILLS_DIR"

echo "CLAUDE.md"
install_claude_md

echo "Skills: $REPO_DIR → $AGENT_SKILLS_DIR, linked from $CLAUDE_SKILLS_DIR"
for skill_md in "$REPO_DIR"/*/SKILL.md; do
  [[ -f $skill_md ]] || continue
  name="$(basename "$(dirname "$skill_md")")"
  install_skill "$name"
  link_skill "$name"
done
prune_dangling_links

if ((BACKED_UP)); then
  echo "Replaced files were backed up to $BACKUP_DIR"
fi
