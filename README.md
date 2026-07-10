# Agent Skills

A collection of agent skills that extend capabilities across planning, development, and tooling.

## Installation

If you trust me, you can install all the skills in this repository with the following command.

```bash
# List all the Available Skills
npx skills@latest add robmellett/skills --list

# Install all skills globally
npx skills@latest add robmellett/skills --skill * --global

# Install a specific skill
npx skills@latest add robmellett/skills --skill specific-skill
```

## Maintenance

```bash
# PUSH (repo → live). -n = dry run; drop it to apply.
rsync -av \
  --exclude='.git/' --exclude='.DS_Store' --exclude='.claude/' \
  "$HOME/.agents/skills/" "/Users/$USER/Code/robmellett-skills/"

# PULL (live → repo)
rsync -av --delete  \
  --exclude='.git/' --exclude='.DS_Store' --exclude='.claude/' --exclude="README.md" \
  "$HOME/.agents/skills/" "/Users/$USER/Code/robmellett-skills/"
```

## Claude

### Set up symlinks in Claude.

```bash
for d in ~/.agents/skills/*/; do
  name=$(basename "$d")
  ln -sfn "../../.agents/skills/$name" ~/.claude/skills/"$name"
done
```

### Fix Symlinks in Claude

```bash
# preview broken symlinks
find -L ~/.claude/skills -maxdepth 1 -type l

# delete them (real dirs are untouched — only broken symlinks match)
find -L ~/.claude/skills -maxdepth 1 -type l -delete
```
