---
name: spatie-version-control
description: Apply Spatie's version control guidelines for any task that creates branches, writes commit messages, opens pull requests, merges, rebases, or names repositories. Use when starting work on a new branch, committing changes, squashing or rewriting history, cleaning up local branches, or reviewing whether a branch name or commit message follows convention.
license: MIT
metadata:
  author: Spatie
---

# Spatie Version Control Guidelines

## Overview
Apply Spatie's version control guidelines so branches, commits, and merges stay predictable and `main` stays stable.

## When to Activate
- Activate when creating a branch, or when asked what to call one.
- Activate when writing a commit message, amending, or squashing.
- Activate when opening a pull request, merging, or rebasing.
- Activate when naming a new repository.
- Activate when reviewing a branch name, commit history, or PR for convention compliance.

## Scope
- In scope: branch names, commit messages, merge/rebase strategy, pull requests, repo naming, local branch hygiene.
- Out of scope: CI/CD pipeline config, release tagging and changelogs, code style (see `spatie-laravel-php`), hosting or deploy mechanics.

## Core Rules (Summary)
- Once a project is live, `main` must always be stable.
- **Every branch name is prefixed with `feature/`, `hotfix/`, or `chore/`.** No other prefixes.
- Commit messages are written in the present tense.
- Prefer granular commits over one bundled commit.
- Squash feature branches when merging into `main`.
- Rebase regularly to keep conflicts small.

## Branch Naming (required)

A branch name **must** be prefixed with one of:

| Prefix | Use for |
| --- | --- |
| `feature/` | New functionality, enhancements, refactors that add or change behaviour |
| `hotfix/` | Fixes to something broken, especially on live |
| `chore/` | Dependency bumps, tooling, config, docs, cleanup — no behaviour change |

After the prefix, use lowercase letters, numbers, and hyphens only.

✅ Good:
```
feature/mailchimp-subscriber-sync
feature/2fa-login
hotfix/vat-calculation-delivery-costs
chore/bump-laravel-12
chore/drop-unused-migrations
```

❌ Bad:
```
mailchimp              # no prefix
feature/Mailchimp      # not lowercase
feature/mailchimp_sync # underscores
bugfix/vat             # not one of the three prefixes
random-things          # not descriptive, no prefix
develop                # reserved branch name
```

> Deviation from upstream Spatie: Spatie's published guideline uses hyphenated names without a slash (`feature-mailchimp`). This project requires the slashed prefixes above — they win over the upstream rule.

## Branch Strategy
- **Before launch:** keep `main` and `develop`. Branch from `develop`, and merge back into `develop`. Avoid committing directly to `main`.
- **After launch:** delete `develop`. Every change reaches `main` through a prefixed branch, squashed on merge.

## Commits
- Present tense, describing what the commit does: `Fix vat calculation in delivery costs`, `Update deps`.
- Not `Updated deps`, `wip`, `commit`, `a lot`, `solid`.
- Split work into meaningful commits: `Fix add to cart button` + `Fix cart count on home` beats `Cart fixes`.
- Use `git add -p` to stage chunks when one edit session spans several logical changes.

## Pull Requests
Pull requests are optional but worth opening when you want peer review, a mergeability check before squashing, or a durable record of why a change was made.

## Merging and Rebasing
```bash
git merge <branch> --squash   # deploy a feature branch into main
git rebase                    # when a push is denied, or to stay current
```

## Workflow
1. Identify the kind of work: new behaviour (`feature/`), a fix (`hotfix/`), or maintenance (`chore/`).
2. Branch from `develop` pre-launch, or from `main` post-launch, using the prefixed name.
3. Commit granularly in the present tense; rebase as the base branch moves.
4. Open a PR if review or a record is wanted; squash on merge into `main`.
5. Read `references/spatie-version-control-guidelines.md` for repo naming and history-rewriting recipes.

## References
- `references/spatie-version-control-guidelines.md`
