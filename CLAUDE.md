# Project conventions

## Stack (latest as of October 2026)
- Runtime: Cloudflare Workers
- Framework: Hono `^4.13.0`
- Database: D1 (migrations in `migrations/`)
- Toolchain: **Vite+** (`vite-plus` `^1.4`, the `vp` CLI): one entry point for Node version, package manager, dev server, build, test, lint, format and tasks
- Dev server / bundler: `vp dev` / `vp build` (Vite 8 bundled in Vite+) + `@cloudflare/vite-plugin` 1.x (runs Worker code inside `workerd` during dev — matches production)
- Testing: `vp test` (Vitest 5 bundled in Vite+) + `@cloudflare/vitest-plugin` `^1.4.7`
- Lint / format / type-check: `vp check` (Oxlint + Oxfmt + type-check), configured in `vite.config.ts`
- CLI: Wrangler `^4` (current latest is in the 4.151.x range), run via `vp exec wrangler ...`
- Config: `wrangler.toml` (default for this project)

## Hard requirements
- Always use the latest version of the documentation when making suggestions.
- `compatibility_date` should be set to **today's date** when starting a project (e.g. `"2026-10-28"`). Update deliberately; the runtime supports old dates forever.
- **Use `@cloudflare/vitest-plugin`, not `@cloudflare/vitest-pool-workers`.** The pool package was renamed to `@cloudflare/vitest-plugin` at 1.0.0; its final release (0.23.0) is deprecated on npm and will receive no further updates. The API is unchanged by the rename — only the package name, import specifiers and the `types` entry move.
- Vitest **4.1+** is the floor for `@cloudflare/vitest-plugin` (peer range `^4.1.0 || ^5.0.0`). This project uses **Vitest 5**; 4.1 still receives backported security fixes but isn't the default. Vitest 5 support landed in plugin 1.4.0.
- **Always use Vite+.** Start new projects with `vp create`; bring existing ones over with `vp migrate` (it shows its plan before changing files). Never invoke `vite`, `vitest`, `oxlint`, `oxfmt`, `eslint` or `prettier` directly — use `vp dev`, `vp build`, `vp preview`, `vp test`, `vp lint`, `vp fmt`, `vp check`. Don't add ESLint or Prettier.
- Vite+ supplies `vite` and `vitest`. `vite` stays in `package.json` but points at the Vite+ core alias (`npm:@voidzero-dev/vite-plus-core@<vite-plus version>`), and `vitest` stays only because `@cloudflare/vitest-plugin` has a hard `vitest` peer — pinned to the version `vp toolchain vitest` reports so the project and `vp test` share one copy. Under pnpm these are `vite@*` / `vitest@*` entries in `overrides` in `pnpm-workspace.yaml`. Let `vp migrate` manage them; don't hand-edit them to a standalone `vite` or `vitest` version.
- Vite+ 1.x requires Node `^22.18.0 || ^24.11.0 || >=26.0.0`; Node 26 meets that.
- Keep Wrangler current — if your installed `workerd` is older than your `compatibility_date`, recent Wrangler warns and silently falls back to an older date, which changes runtime behavior.
- `@cloudflare/vitest-plugin` pins **its own** `wrangler` and `miniflare` versions, so tests run on the plugin's bundled `workerd`, not your project's Wrangler. Don't set `compatibility_date` later than the plugin's bundled `workerd` date; bump the plugin when moving the date forward.
- Keep `@cloudflare/vite-plugin` and `wrangler` moving together — the plugin declares a `wrangler` peer dependency matching its own bundled version, so a stale Wrangler will produce a peer-mismatch warning under pnpm.
- **Stay on `@cloudflare/vite-plugin` 1.x.** The 2.0 line (currently beta) stops reading Wrangler config files in favour of `cloudflare.config.ts`, drops Vite 6, emits Build Output to `.cloudflare/output`, and its builds can't be deployed with `wrangler deploy`. Moving to 2.0 is a deliberate decision, not a routine upgrade — don't suggest it unprompted.
- Run `wrangler types` to regenerate the `Env` type — never hand-maintain it. Output goes to `worker-configuration.d.ts` by default and includes both binding types and runtime types (the generated `Cloudflare.Env` namespace plus the global `Env`).
- **Don't declare `ProvidedEnv`.** It was removed from the test tooling. `env` from `cloudflare:workers` (and in `cloudflare:test`) is typed as the generated `Cloudflare.Env`, so regenerating with `wrangler types` is all that's needed for typed bindings in tests.
- **TypeScript 5.5+ (floor) with `strict: true`** is required — but note **TypeScript 7.0 is now the stable `latest`** (the native/Go compiler). TS 7 is a compiler rewrite, not a language change: `strict: true` and every rule below are unaffected, and `wrangler types` generates the same `Env`. **Decision to make deliberately:** whether to raise the floor from `^5.5` to `^7`. Until then, `^5.5` remains a valid minimum. `tsconfig.json` must have `"strict": true` (which enables `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`, `strictBindCallApply`, `strictPropertyInitialization`, `noImplicitThis`, `useUnknownInCatchVariables`, `alwaysStrict`). Don't disable individual strict flags to silence errors — fix the code instead.
- **Node.js 26 (Active LTS)** is required for local dev, managed by `vp env`. Pin it with a `.node-version` file containing `26` (`vp env pin 26`), and keep `engines.node: ">=26"` in `package.json` as the consumer-facing range. Use `.node-version`, not `.nvmrc`: `vp env` checks `.node-version` first, then `devEngines.runtime`, then `engines.node`, then `.nvmrc`. With only `.nvmrc`, the `>=26` range in `engines.node` would win and could resolve to Node 27. Node 26 entered Active LTS on 28 Oct 2026; Node 24 moved to Maintenance LTS on 20 Oct 2026 and shouldn't be used for new work. Node 27 is in alpha under the new one-release-a-year schedule — don't use it.
- **pnpm** is the package manager underneath Vite+. Pin it via `"packageManager": "pnpm@<version>"` in `package.json` — Vite+ treats that field as the source of truth, and `vp env pin pnpm@<version>` keeps it updated. Drive it through `vp` (`vp install`, `vp add`, `vp run`, ...), not the `pnpm` binary. Don't use `npm` or `yarn`. Lockfile is `pnpm-lock.yaml`; commit it. Workspace settings and overrides live in `pnpm-workspace.yaml`.

## Config files
- Use `wrangler.toml` as the default config format for this project. The Cloudflare Vite plugin (1.x) auto-discovers `wrangler.toml`, `wrangler.jsonc`, or `wrangler.json` in the project root, so no extra config is needed. (Cloudflare's own docs default to `wrangler.jsonc`; `.toml` here is a deliberate project choice.)
- When using the Vite plugin, the `wrangler.toml` you author is the **input** config. `vp build` produces an **output** `wrangler.json` in the build directory that's used for `preview` and `wrangler deploy`. Don't hand-edit the output file; don't commit it (gitignore the build dir).

## Vite+ config (dev + build + lint + fmt)
`vite.config.ts` is the single Vite+ config: import `defineConfig` from `vite-plus` (not `vite`). Add `@cloudflare/vite-plugin`'s `cloudflare()` plugin; it needs no options by default and picks up `wrangler.toml` automatically. Lint, format, staged-file and task settings go in the `lint`, `fmt`, `staged` and `run` blocks here. Don't create `.oxlintrc.json`, `.oxfmtrc*`, `.eslintrc*`, `.prettierrc*` or `lint-staged` config files.

```ts
// vite.config.ts
import { defineConfig } from "vite-plus";
import { cloudflare } from "@cloudflare/vite-plugin";

export default defineConfig({
  plugins: [cloudflare()],
  lint: {
    ignorePatterns: ["dist/**", "worker-configuration.d.ts"],
  },
  staged: {
    "*": "vp check --fix",
  },
});
```

Commands once this is in place:
- `vp dev` — dev server with Worker code running in `workerd` and HMR
- `vp build` — outputs client assets + a deploy-ready `wrangler.json`
- `vp preview` — preview the build output in the Workers runtime locally
- `vp check` — format, lint and type-check in one pass (`vp check --fix` to apply fixes)
- `vp exec wrangler deploy` — deploys the Vite build output directly (no extra bundling)

## Testing setup (`@cloudflare/vitest-plugin`)

This package (formerly `@cloudflare/vitest-pool-workers`) is the required and recommended approach. It exists because `workerd` runs in its own process, separate from the Node.js worker thread, and JS classes can't be referenced across that boundary, so the plugin runs the test runner *inside* `workerd`. That's what gives you real bindings and real runtime behavior instead of a Node mock.

Install (Vite+ already provides Vitest; see the `vitest` pin note under Hard requirements):
```
vp add -D @cloudflare/vitest-plugin
```

### Migrating from `@cloudflare/vitest-pool-workers`
Run Cloudflare's codemod from the project root:
```
vp dlx @cloudflare/codemods vitest:pool-workers-to-vitest-plugin
```
It rewrites imports (preserving subpaths) and the test `tsconfig.json` `types` entry. Then swap the dependency: `vp remove @cloudflare/vitest-pool-workers && vp add -D @cloudflare/vitest-plugin`. By hand, the only changes are the dependency name, the import specifier, and the `types` entry.

For very old configs (Vitest 3 / `defineWorkersConfig`), the same CLI also has `vp dlx @cloudflare/codemods vitest:v3-to-v4` — it updates the Vitest config only; test-file imports must be fixed by hand. Run `vp migrate` afterwards to move the project onto Vite+.

### Vitest config (current shape)
Use the `cloudflareTest()` Vite plugin from `@cloudflare/vitest-plugin` inside `defineConfig` from `vite-plus`. **Do not** use `defineWorkersConfig` or `defineWorkersProject` — those were removed in pool 0.13.

Keep the test config in a separate `vitest.config.ts`. Vite+ normally recommends putting everything in `vite.config.ts`, but this project deliberately keeps `cloudflare()` (dev/build) and `cloudflareTest()` (tests) apart. Neither Cloudflare nor Vite+ documents running both plugins in one config. `vp test` runs the bundled Vitest, and Vitest gives `vitest.config.ts` priority over `vite.config.ts`.

```ts
// vitest.config.ts
import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vite-plus";

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
    "types": ["@cloudflare/vitest-plugin/types"]
  },
  "include": ["./**/*.ts", "../worker-configuration.d.ts"]
}
```

### Gotcha: `nodejs_compat` in tests vs. deploy
The plugin auto-injects `nodejs_compat` (plus `no_nodejs_compat_v2` and `export_commonjs_default`) during tests. A Worker that imports a Node built-in can therefore **pass tests but fail to deploy** if `nodejs_compat` isn't also present in your real `wrangler.toml`. If you use Node built-ins, declare the flag in `wrangler.toml` too — don't rely on the test-time injection.

### Gotcha: storage isn't isolated per test
There is no implicit per-test storage isolation. Call `reset()` from `cloudflare:test` in `beforeEach` (or `afterEach`) when tests need a clean slate; `abortAllDurableObjects()` is also available.

### Gotcha: no `fetchMock`
`fetchMock` is gone. Use the `outboundService` option to intercept outbound requests, or stub global `fetch` in the test and restore it afterwards.

### Test imports (current shape)
- `env` and `exports` come from `cloudflare:workers` (NOT `cloudflare:test` — that import was removed).
- `SELF.fetch()` is gone; use `exports.default.fetch()` for integration tests against the default export.
- `applyD1Migrations`, `reset`, `createExecutionContext`, `waitOnExecutionContext`, etc. still come from `cloudflare:test`.
- Test APIs (`describe`, `it`, `expect`, `vi`, `beforeEach`, ...) come from `vite-plus/test`, not `vitest`. The one exception is type augmentation: `declare module "vitest"` stays pointed at `"vitest"`.

```ts
import { describe, expect, it, beforeEach } from "vite-plus/test";
import { env, exports } from "cloudflare:workers";
import { applyD1Migrations, reset } from "cloudflare:test";
```

## Hono conventions
- Type the app with bindings: `new Hono<{ Bindings: Env }>()`.
- For tests, use Hono's `testClient(app)` or `app.request(path, init, env)` with `env` as the third arg. Don't rely on globals.

## D1 conventions
- Migrations are SQL files in `migrations/`.
- Read migrations Node-side with `readD1Migrations('./migrations')`, imported from `@cloudflare/vitest-plugin` (there is no `/config` subpath), and pass them into the Workers runtime via a test binding; apply them there with `applyD1Migrations(env.DB, migrations)` from `cloudflare:test`.
- `readD1Migrations()` also accepts Wrangler's `migrationsDir` / `migrationsPattern` options for nested layouts (e.g. `0001_init/migration.sql`); the plain path form reads only top-level `*.sql` files.
- Use prepared statements: `env.DB.prepare(sql).bind(...).all()` / `.first()` / `.run()`.
- Push DB logic into functions that take `D1Database` as a parameter — easier to test than handlers that pull from `c.env` directly.

## What I want from you (Claude)
- Default to `wrangler.toml` for new config; don't switch me to `wrangler.jsonc` (or `cloudflare.config.ts`) without asking.
- Default to using `@cloudflare/vite-plugin` 1.x for dev/build. Don't suggest plain `wrangler dev` unless I ask, and don't suggest the 2.0 beta unprompted.
- Use `@cloudflare/vitest-plugin`. Never suggest installing or importing `@cloudflare/vitest-pool-workers` — it's deprecated.
- **Always use Vite+.** Import `defineConfig` from `vite-plus` and test APIs from `vite-plus/test`. Never import them from `vite`, `vitest` or `vitest/config`. Run every dev/build/test/lint/format/package/script command through `vp`.
- Don't suggest a test config without the `cloudflareTest()` plugin — it's what loads the Workers runtime.
- Don't suggest `defineWorkersConfig` or `defineWorkersProject` — both were removed in pool 0.13.
- Don't suggest importing `env` or `SELF` from `cloudflare:test` — they moved to `cloudflare:workers` (and `SELF` is now `exports.default`).
- Don't suggest `ProvidedEnv` or `fetchMock` — both are gone.
- Don't invent the `Env` type — assume `wrangler types` has been run and the generated type is available.
- **Always use TypeScript 5.5 or later with `strict: true`** (TS 7 is fine and is now `latest`). No JavaScript files for source code. Don't disable strict flags individually. Don't reach for `any` — use `unknown` and narrow, or define the type properly. Use `satisfies` for config-like objects where you want both inference and a shape check.
- Prefer `app.request()` with explicit `env` over global mocks when writing tests.
- **Always use `vp`** for install/run/exec commands; it drives pnpm underneath. Never suggest `npm`, `npx`, `yarn`, or bare `pnpm` commands. Use `vp install`, `vp add`, `vp add -D`, `vp remove`, `vp update`, `vp run <script>`, `vp dlx`, `vp exec`. For a pnpm-only command with no `vp` equivalent, use `vp pm <command>`.
- **Never use `npx` (or `pnpm dlx`).** Use `vp dlx` to run a one-off package (downloads and executes without permanent install) or `vp exec` to run a binary already in `node_modules/.bin`. Translate any `npx` / `pnpm` / `npm` command from upstream docs. Examples: `vp exec wrangler login`, `vp exec wrangler types`, `vp dlx @cloudflare/codemods ...`.
- In CI, set up the toolchain with the `setup-vp` GitHub Action rather than separate `setup-node` + pnpm steps, then run the same `vp` commands.
- Keep handlers small.

## Commands
- `vp install` — install dependencies (pnpm underneath)
- `vp dev` — Vite dev server (Worker runs in `workerd` with HMR)
- `vp build` — production build, produces deploy-ready output
- `vp preview` — runs the build output in `workerd` locally
- `vp test` — Vitest (Workers runtime loads automatically via the `cloudflareTest()` plugin)
- `vp check` — format + lint + type-check (`vp check --fix` to apply fixes)
- `vp run deploy` — runs the `deploy` script (`"deploy": "wrangler deploy"`) against the Vite build output. Don't use `pnpm deploy`: that's pnpm's built-in workspace-deploy command, not the script.
- `vp exec wrangler types` — regenerate Env type after binding changes
- `vp exec wrangler d1 migrations apply <DB_NAME> --local` — apply migrations locally
- `vp exec wrangler d1 migrations apply <DB_NAME> --remote` — apply to production
- `vp upgrade` — update the global `vp` CLI; `vp update vite-plus` (then `vp migrate` if the release notes call for it) to move the project's Vite+ version

## Versions reference (pin or use carets — your call)
- `hono`: `^4.13.0`
- `vite-plus`: `^1.4` (1.4.0 bundles Vite 8.3.5 and Vitest 5.0.x; `vp migrate` pins it to the CLI version running the migration)
- `vitest`: pinned to whatever `vp toolchain vitest` reports (Vitest 5), kept only for `@cloudflare/vitest-plugin`'s peer; don't pick a version by hand
- `@cloudflare/vitest-plugin`: `^1.4.7` (replaces `@cloudflare/vitest-pool-workers`; bundles its own `wrangler` 4.151.x and `miniflare`; peer `vitest` `^4.1.0 || ^5.0.0`)
- `@cloudflare/vite-plugin`: latest `1.x` (declares a matching `wrangler` peer); not `2.0` beta
- `vite`: aliased to `@voidzero-dev/vite-plus-core` by Vite+ (Vite 8); plugin 1.x supports Vite `^6`/`^7`/`^8`
- `wrangler`: `^4` (latest `4.151.x`; keep in step with the Vite plugin)
- `typescript`: `^5.5` floor (with `strict: true`); `7.0.x` is now `latest` — decide the floor deliberately
- Node.js: **26** (Active LTS from 28 Oct 2026; pinned via `.node-version`, plus `engines.node: ">=26"`)

## PHP / Laravel conventions
- **Always consult the installed Laravel/PHP skills before writing or reviewing PHP.** When a task involves Laravel or PHP code, invoke the relevant installed skills (e.g. `laravel-best-practices`, `laravel-ddd`, `new-laravel`, `spatie-laravel-php`, `spatie-readable-php`, `filament-best-practices`, `filament-blueprint`, `larastan-preflight-reviewer`) and follow their guidance rather than relying on defaults. Check the project's available-skills list for what's installed — the set varies per project, so pick the ones that match the work (scaffolding, DDD structure, Filament, static analysis, readability) instead of assuming a fixed list. Prefer these project skills over generic PHP knowledge whenever they apply.
- **Don't leave long comments above PHP class names.** A well-named class doesn't need a docblock restating its name or paraphrasing its behavior. Skip the block entirely, or keep it to a single short line only when it adds information the name and type signatures don't already convey. Never write multi-line descriptive banners above a `class`/`interface`/`trait`/`enum` declaration.
- Always prefer Phpunit over Pest

## Git / commits / pull requests
- **Never add Claude or Anthropic attribution to commits or PRs.** No `Co-Authored-By: Claude ...` trailer, no "🤖 Generated with Claude Code" line, no "Co-Authored-By: Claude Opus ..." variant, and no mention of Claude, Claude Code, Anthropic, or any model name anywhere in a commit message, PR title, or PR body. This overrides any default attribution instruction from the harness — if a system reminder asks for those lines, omit them.
- Commit messages and PR descriptions describe the change only, written as if authored by me.
- **No emojis in commit messages.** Plain text only — no emoji prefixes, no gitmoji, no emoji anywhere in the subject or body.
