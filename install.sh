#!/usr/bin/env zsh

case "$(uname -s)" in
  Darwin)
    SOURCE_DIR="/Users/$USER/Code/robmellett-skills/"
    ;;
  Linux)
    SOURCE_DIR="/home/rob/Code/robmellett-skills/"
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

rsync -av \
  --exclude='.git/' --exclude='.DS_Store' --exclude='.claude/' \
  "$SOURCE_DIR" "$HOME/.agents/skills/"


for d in ~/.agents/skills/*/; do
  name=$(basename "$d")
  ln -sfn "../../.agents/skills/$name" ~/.claude/skills/"$name"
done
