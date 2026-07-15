---
name: github-actions
description: >
  Set up or fix GitHub Actions that deploy Cloudflare Workers / Hono projects
  with Wrangler. Use when creating a deploy/CI workflow under `.github/workflows`,
  wiring `cloudflare/wrangler-action`, running D1 migrations in CI, or fixing the
  "Node.js 20 actions are deprecated" (Node 20 → Node 24) wrangler-action
  warning. Triggers on github actions, wrangler-action, wrangler deploy on push,
  node 20 deprecated.
---

# GitHub Actions — deploy Cloudflare Workers

Ship a Workers/Hono project to Cloudflare on push, on the project stack: pnpm, Node 24, the `@cloudflare/vite-plugin` build, D1, and `cloudflare/wrangler-action`.

## Fix: "Node.js 20 actions are deprecated"

That warning fires because `cloudflare/wrangler-action@v3` declares `runs.using: node20` in its `action.yml`, and GitHub [deprecated Node 20 on runners](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/). Runners already force these actions onto Node 24 (default since 2026-06-02) and drop Node 20 entirely on 2026-09-16.

**The fix is a one-line bump — `@v3` → `@v4`.** `wrangler-action@v4` declares `runs.using: node24`, so the warning is gone. It also defaults to installing Wrangler v4, which matches the stack.

```diff
-      - uses: cloudflare/wrangler-action@v3
+      - uses: cloudflare/wrangler-action@v4
```

The same warning appears for **any** action pinned to a stale major that still runs on Node 20 (an old `actions/checkout@v3`, `actions/setup-node@v3`, …). Keep every action on a current major — the table below is the single source of truth.

## Current action majors

Pin to the **major tag** (`@v4`) so security and patch releases flow in automatically. Verify a major is still current with `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name` before you write it.

| Action | Pin | Runtime |
| --- | --- | --- |
| `cloudflare/wrangler-action` | `@v4` | node24 |
| `actions/checkout` | `@v7` | node24 |
| `actions/setup-node` | `@v7` | node24 |
| `pnpm/action-setup` | `@v6` | node24 |

_(Current as of 2026-07. These are the whole reason the warning does or doesn't appear — a Node20-era major is a Node20-era warning.)_

## The deploy workflow

`.github/workflows/deploy.yml` — deploys on push to `main`, runs D1 migrations first:

```yaml
name: Deploy

on:
  push:
    branches: [main]

# One deploy at a time; a newer push cancels an in-flight run.
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      # pnpm/action-setup MUST come before setup-node so setup-node's
      # `cache: pnpm` can find pnpm on PATH. Version comes from the
      # `packageManager` field in package.json — no `version:` needed.
      - uses: pnpm/action-setup@v6

      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc   # pins Node 24 from your .nvmrc
          cache: pnpm

      - run: pnpm install --frozen-lockfile

      # Vite plugin: build produces the deploy-ready output that
      # `wrangler deploy` reads. Build MUST run before deploy.
      - run: pnpm build

      # Remove this step if the project has no D1 database.
      - name: Apply D1 migrations
        uses: cloudflare/wrangler-action@v4
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: d1 migrations apply <DB_NAME> --remote

      - name: Deploy
        uses: cloudflare/wrangler-action@v4
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          # command defaults to `deploy`
```

Replace `<DB_NAME>` with the `database_name` from `wrangler.toml`.

## Why the workflow is shaped this way

Each step below earns its place — the action does less than people assume.

- **`wrangler-action` installs only the wrangler CLI, not your project deps.** It runs `wrangler <command>` (default `deploy`) plus optional `preCommands`/`postCommands` — nothing else. So `pnpm install` and `pnpm build` are your responsibility, as explicit steps before it.
- **Install first, and the action reuses your pinned wrangler.** With `node_modules` populated, the action logs `🔍 Checking for existing Wrangler installation`, finds it, and skips its own install — so CI runs the exact Wrangler version in your lockfile instead of drifting to latest. (That log line is in the deploy output you already see.)
- **Build before deploy.** `pnpm build` (`vite build`) writes the output `wrangler.json` and assets that `wrangler deploy` deploys; without it, deploy has nothing to ship.
- **`pnpm/action-setup` before `setup-node`.** `setup-node`'s pnpm cache needs pnpm already on PATH.
- **Migrate before deploy.** Apply additive D1 migrations while the old code still runs, so the schema is ready when the new code goes live.

## Credentials

Two repo secrets under **Settings → Secrets and variables → Actions**:

- **`CLOUDFLARE_API_TOKEN`** — create at *My Profile → API Tokens*. Start from the **Edit Cloudflare Workers** template. That template does **not** include D1, so if you run migrations, add **Account → D1 → Edit** to the token. Effective scopes: `Workers Scripts:Edit`, `D1:Edit`, `Account Settings:Read`. Scope it to the one account.
- **`CLOUDFLARE_ACCOUNT_ID`** — from any Workers dashboard page. Not secret, but a repo secret keeps it out of the YAML.

Never commit either value. `wrangler-action` reads them from the `apiToken`/`accountId` inputs and exports them to Wrangler as env vars.

## More recipes

For anything past a single push-to-deploy, see [`references/recipes.md`](references/recipes.md): PR preview deployments (versions upload + a comment on the PR), staging/production environments, monorepo `workingDirectory`, SHA-pinning actions for hardening, and Cloudflare's native **Workers Builds** as an alternative to GitHub Actions.
