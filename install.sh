#!/usr/bin/env zsh

rsync -av \
  --exclude='.git/' --exclude='.DS_Store' --exclude='.claude/' \
  "/Users/$USER/Code/robmellett-skills/" "$HOME/.agents/skills/"


for d in ~/.agents/skills/*/; do
  name=$(basename "$d")
  ln -sfn "../../.agents/skills/$name" ~/.claude/skills/"$name"
done
