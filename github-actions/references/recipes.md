# Recipes

Extensions to the canonical deploy workflow in [`SKILL.md`](../SKILL.md). Each is optional — reach for the one the task needs. All keep the same version pins from the SKILL.md table.

## PR preview deployments

Upload a **version** (no traffic shift) on every PR and comment its preview URL. `wrangler versions upload` writes a version-upload artifact whose `preview_url` the action surfaces as the `deployment-url` output.

```yaml
name: Preview

on:
  pull_request:

permissions:
  contents: read
  pull-requests: write   # to comment on the PR

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: pnpm/action-setup@v6
      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - name: Upload preview version
        id: preview
        uses: cloudflare/wrangler-action@v4
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: versions upload

      - name: Comment preview URL
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR: ${{ github.event.pull_request.number }}
          URL: ${{ steps.preview.outputs.deployment-url }}
        # `gh` is preinstalled on the runner; --edit-last keeps one sticky comment.
        run: |
          gh pr comment "$PR" --edit-last --create-if-none --body "🔎 Preview: $URL"
```

Preview URLs require `workers_dev` preview URLs on the Worker (on by default). `versions upload` needs the same token scopes as deploy.

## Staging / production environments

Define named environments in `wrangler.toml`:

```toml
name = "my-app"

[env.staging]
name = "my-app-staging"

[env.production]
name = "my-app-production"
```

Pass the target with the action's `environment` input (maps to `wrangler deploy --env <name>`):

```yaml
      - name: Deploy production
        uses: cloudflare/wrangler-action@v4
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          environment: production
```

For approval gates, add a GitHub **Environment** (Settings → Environments) with required reviewers, and reference it on the job:

```yaml
jobs:
  deploy:
    environment: production   # GitHub gate — distinct from wrangler's --env
    runs-on: ubuntu-latest
```

The two `environment`s are unrelated: the job-level one is GitHub's protection rule; the action input is Wrangler's config section. D1 migrations for a named env: `command: d1 migrations apply <DB_NAME> --env production --remote`.

## Monorepo

Point the action at the package that holds `wrangler.toml`:

```yaml
      - name: Deploy
        uses: cloudflare/wrangler-action@v4
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          workingDirectory: ./apps/api
```

Run the earlier `pnpm build` against the same workspace (`pnpm --filter api build`). Scope the trigger so unrelated changes don't redeploy:

```yaml
on:
  push:
    branches: [main]
    paths: ["apps/api/**"]
```

## Harden with SHA pins

Major tags (`@v4`) are mutable — a compromised tag runs your token. For untrusted or high-value repos, pin the full commit SHA and let Dependabot bump it:

```yaml
      - uses: cloudflare/wrangler-action@<full-40-char-sha>  # v4.0.0
```

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```

Dependabot keeps SHA-pinned actions current, which also keeps them off deprecated Node versions.

## Alternative: Workers Builds (no GitHub Actions)

Cloudflare's **Workers Builds** connects the repo directly (dashboard → the Worker → *Settings → Builds → Connect*). Cloudflare runs the build and deploy on push — no `CLOUDFLARE_API_TOKEN` in GitHub, no workflow file. Trade-offs: build runs on Cloudflare's infrastructure, and CI checks (tests, typecheck) still belong in GitHub Actions. Use GitHub Actions when the same pipeline must gate deploys on tests; use Workers Builds for the simplest possible deploy-on-push.
