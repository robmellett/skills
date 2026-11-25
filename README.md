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

Both scripts are plain bash (3.2+) with no rsync/diffutils dependency, so they run
on macOS and Omarchy/Arch alike. Pass `-n` to either for a dry run.

```bash
# PUSH (repo → live)
./install.sh

# PULL (live → repo): copies ~/.claude/CLAUDE.md and ~/.agents/skills/* into the repo
./backup.sh
```

`install.sh`:

- copies every skill (a top-level dir with a `SKILL.md`) into `~/.agents/skills/<skill>`
- links `~/.claude/skills/<skill> -> ../../.agents/skills/<skill>`, so Claude always reads the agents copy
- installs `CLAUDE.md` to `~/.claude/CLAUDE.md`
- removes Claude symlinks into `~/.agents/skills` that no longer resolve

Before replacing anything that differs from the repo — the live `CLAUDE.md`, a live
skill dir, or a real directory where a Claude symlink belongs — it moves it to
`~/.agents/backups/<timestamp>/`.

`backup.sh` always copies `~/.claude/CLAUDE.md` back into the repo, then mirrors each
skill in `~/.agents/skills`. Review `git diff` before committing.
