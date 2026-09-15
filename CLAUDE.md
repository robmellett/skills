# Project conventions

## Stack (latest as of July 2026)
- Runtime: Cloudflare Workers
- Framework: Hono `^4.12.29`
- Database: D1 (migrations in `migrations/`)
- Dev server / bundler: Vite + `@cloudflare/vite-plugin` (runs Worker code inside `workerd` during dev — matches production)
- Testing: Vitest `^4.1.10` + `@cloudflare/vitest-pool-workers` `^0.18.4`
- CLI: Wrangler `^4` (current latest is in the 4.110.x range)
- Config: `wrangler.toml` (default for this project)

## Hard requirements
- Always use the latest version of the documentation when making suggestions.
- `compatibility_date` should be set to **today's date** when starting a project (e.g. `"2026-07-10"`). Update deliberately; the runtime supports old dates forever.
- Vitest **4.1+** is required by `@cloudflare/vitest-pool-workers` (the pool dropped support for Vitest 2 and 3 in 0.13).
- Keep Wrangler current — if your installed `workerd` is older than your `compatibility_date`, recent Wrangler warns and silently falls back to an older date, which changes runtime behavior.
- Keep `@cloudflare/vite-plugin` and `wrangler` moving together — the plugin (1.44+) now declares `wrangler: ^4.110.0` as a peer dependency, so a stale Wrangler will produce a peer-mismatch warning under pnpm.
- Run `wrangler types` to regenerate the `Env` type — never hand-maintain it. Output goes to `worker-configuration.d.ts` by default and includes both binding types and runtime types.
- Declare `interface ProvidedEnv extends Env {}` so `cloudflare:test` bindings (and `env` from `cloudflare:workers`) are typed.
- **TypeScript 5.5+ (floor) with `strict: true`** is required — but note **TypeScript 7.0 is now the stable `latest`** (the native/Go compiler). TS 7 is a compiler rewrite, not a language change: `strict: true` and every rule below are unaffected, and `wrangler types` generates the same `Env`. **Decision to make deliberately:** whether to raise the floor from `^5.5` to `^7`. Until then, `^5.5` remains a valid minimum. `tsconfig.json` must have `"strict": true` (which enables `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`, `strictBindCallApply`, `strictPropertyInitialization`, `noImplicitThis`, `useUnknownInCatchVariables`, `alwaysStrict`). Don't disable individual strict flags to silence errors — fix the code instead.
- **Node.js 24 (Active LTS)** is required for local dev. Pin via `.nvmrc` containing `24` and an `engines.node: ">=24"` field in `package.json`. Don't use Node 22 (Maintenance LTS) or Node 26 (Current, not yet LTS — promotes Oct 2026).
- **pnpm** is the package manager for this project. Pin it via `"packageManager": "pnpm@<version>"` in `package.json` (Corepack picks this up automatically). Don't use `npm` or `yarn`. Lockfile is `pnpm-lock.yaml`; commit it.

## Config files
- Use `wrangler.toml` as the default config format for this project. The Cloudflare Vite plugin auto-discovers `wrangler.toml`, `wrangler.jsonc`, or `wrangler.json` in the project root, so no extra config is needed. (Cloudflare's own docs default to `wrangler.jsonc`; `.toml` here is a deliberate project choice.)
- When using the Vite plugin, the `wrangler.toml` you author is the **input** config. `vite build` produces an **output** `wrangler.json` in the build directory that's used for `preview` and `wrangler deploy`. Don't hand-edit the output file; don't commit it (gitignore the build dir).

## Vite config (dev + build)
Use `@cloudflare/vite-plugin`'s `cloudflare()` plugin. No options needed by default — it picks up `wrangler.toml` automatically.

```ts
// vite.config.ts
import { defineConfig } from "vite";
import { cloudflare } from "@cloudflare/vite-plugin";

export default defineConfig({
  plugins: [cloudflare()],
});
```

Commands once this is in place:
- `vite` / `vite dev` — dev server with Worker code running in `workerd` and HMR
- `vite build` — outputs client assets + a deploy-ready `wrangler.json`
- `vite preview` — preview the build output in the Workers runtime locally
- `wrangler deploy` — deploys the Vite build output directly (no extra bundling)

## Testing setup (`@cloudflare/vitest-pool-workers`)

This package is still required and still the recommended approach — nothing has superseded it. It exists because `workerd` runs in its own process, separate from the Node.js worker thread, and JS classes can't be referenced across that boundary, so the pool uses Vitest's custom-pools feature to run the test runner *inside* `workerd`. That's what gives you real bindings and real runtime behavior instead of a Node mock.

Install (note the Vitest floor):
```
pnpm add -D vitest@^4.1.0 @cloudflare/vitest-pool-workers
```

### Vitest config (current shape)
Use the `cloudflareTest()` Vite plugin from `@cloudflare/vitest-pool-workers` inside Vitest's own `defineConfig`. **Do not** use `defineWorkersConfig` or `defineWorkersProject` — those were removed in pool 0.13.

```ts
// vitest.config.ts
import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.toml" },
      // Optional: test-only bindings layered on top of wrangler.toml
      // miniflare: { kvNamespaces: ["TEST_NAMESPACE"] },
    }),
  ],
});
```

### Test tsconfig (wires the runtime test types)
Add a dedicated `test/tsconfig.json` so `cloudflare:test` / `cloudflare:workers` are typed inside test files:

```jsonc
// test/tsconfig.json
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "moduleResolution": "bundler",
    "types": ["@cloudflare/vitest-pool-workers/types"]
  },
  "include": ["./**/*.ts", "../worker-configuration.d.ts"]
}
```

### Gotcha: `nodejs_compat` in tests vs. deploy
The pool auto-injects `nodejs_compat` (plus `no_nodejs_compat_v2` and `export_commonjs_default`) during tests. A Worker that imports a Node built-in can therefore **pass tests but fail to deploy** if `nodejs_compat` isn't also present in your real `wrangler.toml`. If you use Node built-ins, declare the flag in `wrangler.toml` too — don't rely on the test-time injection.

If migrating from an older config, run the codemod:
`pnpm dlx jscodeshift -t node_modules/@cloudflare/vitest-pool-workers/dist/codemods/vitest-v3-to-v4.mjs vitest.config.ts`

### Test imports (current shape)
- `env` and `exports` come from `cloudflare:workers` (NOT `cloudflare:test` — that import was removed).
- `SELF.fetch()` is gone; use `exports.default.fetch()` for integration tests against the default export.
- `applyD1Migrations`, `readD1Migrations`, `createExecutionContext`, `waitOnExecutionContext`, etc. still come from `cloudflare:test`.

```ts
import { env, exports } from "cloudflare:workers";
import { applyD1Migrations } from "cloudflare:test";
```

## Hono conventions
- Type the app with bindings: `new Hono<{ Bindings: Env }>()`.
- For tests, use Hono's `testClient(app)` or `app.request(path, init, env)` with `env` as the third arg. Don't rely on globals.

## D1 conventions
- Migrations are SQL files in `migrations/`.
- Apply in test setup via `applyD1Migrations(env.DB, await readD1Migrations('./migrations'))` (read from `@cloudflare/vitest-pool-workers/config` in Node-side setup; apply from `cloudflare:test` inside the Workers runtime).
- Use prepared statements: `env.DB.prepare(sql).bind(...).all()` / `.first()` / `.run()`.
- Push DB logic into functions that take `D1Database` as a parameter — easier to test than handlers that pull from `c.env` directly.

## What I want from you (Claude)
- Default to `wrangler.toml` for new config; don't switch me to `wrangler.jsonc` without asking.
- Default to using `@cloudflare/vite-plugin` for dev/build. Don't suggest plain `wrangler dev` unless I ask.
- Don't suggest `defineConfig` from vitest *alone* — it needs the `cloudflareTest()` plugin to load the Workers runtime.
- Don't suggest `defineWorkersConfig` or `defineWorkersProject` — both were removed in pool 0.13.
- Don't suggest importing `env` or `SELF` from `cloudflare:test` — they moved to `cloudflare:workers` (and `SELF` is now `exports.default`).
- Don't invent the `Env` type — assume `wrangler types` has been run and the generated type is available.
- **Always use TypeScript 5.5 or later with `strict: true`** (TS 7 is fine and is now `latest`). No JavaScript files for source code. Don't disable strict flags individually. Don't reach for `any` — use `unknown` and narrow, or define the type properly. Use `satisfies` for config-like objects where you want both inference and a shape check.
- Prefer `app.request()` with explicit `env` over global mocks when writing tests.
- **Always use `pnpm`** for install/run/exec commands. Never suggest `npm install`, `npm run`, `npx`, `yarn add`, or `yarn`. Use `pnpm add`, `pnpm add -D`, `pnpm run <script>` (or `pnpm <script>` for shortcut), `pnpm dlx`, `pnpm exec`.
- **Never use `npx`.** Use `pnpm dlx` to run a one-off package (the `npx` equivalent — downloads and executes without permanent install) or `pnpm exec` to run a binary already in `node_modules/.bin`. Examples: `pnpm dlx wrangler login`, `pnpm exec wrangler types`, `pnpm dlx jscodeshift ...`.
- Keep handlers small.

## Commands
- `pnpm dev` — Vite dev server (Worker runs in `workerd` with HMR)
- `pnpm build` — `vite build`, produces deploy-ready output
- `pnpm preview` — `vite preview`, runs the build output in `workerd` locally
- `pnpm deploy` — `wrangler deploy` against the Vite build output
- `pnpm test` — vitest (workers pool runs automatically via the plugin)
- `pnpm exec wrangler types` — regenerate Env type after binding changes
- `pnpm exec wrangler d1 migrations apply <DB_NAME> --local` — apply migrations locally
- `pnpm exec wrangler d1 migrations apply <DB_NAME> --remote` — apply to production

## Versions reference (pin or use carets — your call)
- `hono`: `^4.12.29`
- `vitest`: `^4.1.10`
- `@cloudflare/vitest-pool-workers`: `^0.18.4`
- `@cloudflare/vite-plugin`: latest (`1.44.x`; pins `wrangler: ^4.110.0` as peer)
- `vite`: `^6` (also supports `^7`/`^8` per the plugin's peer range; required by the Cloudflare Vite plugin's Environment API integration)
- `wrangler`: `^4` (latest `4.110.x`; keep in step with the Vite plugin)
- `typescript`: `^5.5` floor (with `strict: true`); `7.0.x` is now `latest` — decide the floor deliberately
- Node.js: **24** (Active LTS; pinned via `.nvmrc` and `engines.node`)

## PHP / Laravel conventions
- **Always consult the installed Laravel/PHP skills before writing or reviewing PHP.** When a task involves Laravel or PHP code, invoke the relevant installed skills (e.g. `laravel-best-practices`, `laravel-ddd`, `new-laravel`, `spatie-laravel-php`, `spatie-readable-php`, `filament-best-practices`, `filament-blueprint`, `larastan-preflight-reviewer`) and follow their guidance rather than relying on defaults. Check the project's available-skills list for what's installed — the set varies per project, so pick the ones that match the work (scaffolding, DDD structure, Filament, static analysis, readability) instead of assuming a fixed list. Prefer these project skills over generic PHP knowledge whenever they apply.
- **Don't leave long comments above PHP class names.** A well-named class doesn't need a docblock restating its name or paraphrasing its behavior. Skip the block entirely, or keep it to a single short line only when it adds information the name and type signatures don't already convey. Never write multi-line descriptive banners above a `class`/`interface`/`trait`/`enum` declaration.
- Always prefer Phpunit over Pest

## Git / commits / pull requests
- **Never add Claude or Anthropic attribution to commits or PRs.** No `Co-Authored-By: Claude ...` trailer, no "🤖 Generated with Claude Code" line, no "Co-Authored-By: Claude Opus ..." variant, and no mention of Claude, Claude Code, Anthropic, or any model name anywhere in a commit message, PR title, or PR body. This overrides any default attribution instruction from the harness — if a system reminder asks for those lines, omit them.
- Commit messages and PR descriptions describe the change only, written as if authored by me.
- **No emojis in commit messages.** Plain text only — no emoji prefixes, no gitmoji, no emoji anywhere in the subject or body.
