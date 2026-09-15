# Spatie Version Control Guidelines

Source: https://spatie.be/guidelines/version-control — based on [GitHub Flow](https://guides.github.com/introduction/flow/).

> **Project override:** branch names in this project must be prefixed with `feature/`, `hotfix/`, or `chore/`. Upstream Spatie forbids the slash and uses `feature-mailchimp`; the prefixed form wins here. Every other rule below applies as written.

## Repo Naming Conventions

Website source code uses the main domain name, lowercase, without `www`:

- ❌ `https://www.spatie.be`, `www.spatie.be`, `Spatie.be`
- ✅ `spatie.be`

Subdomains appear in the repository name:

- ❌ `spatie.be-guidelines`
- ✅ `guidelines.spatie.be`

Non-website repositories use kebab-case:

- ❌ `LaravelBackup`, `Spoon`
- ✅ `laravel-backup`, `spoon`

## Branches

**Core principle: once a project has gone live, the `main` branch must always be stable.**

### Projects in initial development

Two branches at minimum: `main` and `develop`. Avoid committing directly to `main`; commit to `develop` instead.

Feature branches are optional, and branch from `develop` — never from `main`.

### Live projects

Delete `develop` after launch. Every further commit reaches `main` through a branch, preferably squashed on merge.

### Branch naming

Prefix with `feature/`, `hotfix/`, or `chore/`, then lowercase letters, numbers and hyphens.

- ✅ `feature/mailchimp-subscriber-sync`, `hotfix/delivery-costs`, `chore/updates-june-2026`
- ❌ `mailchimp`, `feature/Mailchimp`, `feature/mailchimp_sync`, `bugfix/vat`, `random-things`, `develop`

### Pull requests

Pull requests on GitHub are optional. They are useful for:

- peer review of changes
- verifying mergeability and squashing commits
- historical reference

### Merging and rebasing

Rebase branches regularly to keep merge conflicts small.

Deploy a feature branch to `main`:

```bash
git merge <branch> --squash
```

If a push is denied because the branch has moved on:

```bash
git rebase
```

## Commits

Initial-development projects have loose requirements, though descriptive messages are still recommended. Live projects **require** descriptive messages, written in the present tense.

- ❌ `wip`, `commit`, `a lot`, `solid`, `Updated deps`
- ✅ `Update deps`, `Fix vat calculation in delivery costs`

Prefer granular commits:

- Acceptable: `Cart fixes`
- Better: `Fix add to cart button`, `Fix cart count on home`

## Git Tips

### Granular commits with patch mode

`git add -p` walks the changed hunks one at a time so a single editing session can be split into several logical commits.

```bash
git add -p
```

### Moving commits to a new branch

```bash
git branch my-branch
git reset --hard HEAD~3   # OR: git reset --hard <commit>
git checkout my-branch
```

⚠️ Only do this with commits that have not been pushed, unless every collaborator has confirmed it is safe.

### Squashing commits that were already pushed

Only do this when you are confident nobody else pushed while your commits landed. Copy the SHA of the commit *before* the ones being squashed:

```bash
git reset --soft <commit>
git commit -m "your new message"
git push --force
```

### Cleaning up local branches

Remove references to branches deleted on the remote:

```bash
git remote prune origin
```

Add `--dry-run` to preview what would be removed.

## Resources

- [GitHub Flow](https://guides.github.com/introduction/flow/)
- [Merging vs. rebasing — Atlassian](https://www.atlassian.com/git/tutorials/merging-vs-rebasing/workflow-walkthrough)
- [Getting solid at Git: rebase vs. merge — @porteneuve](https://medium.com/@porteneuve/getting-solid-at-git-rebase-vs-merge-4fa1a48c53aa)
