# Config and Migrations

## `drizzle.config.ts`

```ts
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  dialect: 'postgresql',          // 'postgresql' | 'mysql' | 'sqlite' | 'turso' | 'singlestore'
  schema: './src/db/schema.ts',   // or a glob: './src/db/**/*.schema.ts'
  out: './drizzle',
  dbCredentials: { url: process.env.DATABASE_URL! },
  verbose: true,
  strict: true,
});
```

Keep `verbose` and `strict` on: `verbose` prints the statements before running them, `strict` asks before applying. Both exist to stop a `push` you didn't mean.

`driver` is only for the odd ones out — `d1-http`, `turso`, `aws-data-api`, `expo`. Every other driver is inferred from `dialect`; setting it unnecessarily is a config error.

The `schema` path is load-bearing: a table outside that glob gets no migration and no error. When adding a schema file, check it matches.

Per-environment configs are separate files: `pnpm drizzle-kit push --config=drizzle-dev.config.ts`.

## Commands

| Command | What it does |
| --- | --- |
| `drizzle-kit generate` | Diff the schema against the last snapshot → write a SQL migration |
| `drizzle-kit migrate` | Apply pending migrations |
| `drizzle-kit push` | Apply the schema straight to the database, no migration files |
| `drizzle-kit pull` | Introspect an existing database → generate `schema.ts` |
| `drizzle-kit check` | Detect conflicting migrations across branches |
| `drizzle-kit studio` | Local database browser |
| `drizzle-kit up` | Upgrade old snapshot files to the current format |
| `drizzle-kit export` | Print the schema as SQL |

```bash
pnpm drizzle-kit generate --name add_posts_table
```

Always pass `--name` — `0003_add_posts_table.sql` is reviewable in a diff; `0003_wandering_iron_man.sql` is not.

Wire them as `package.json` scripts (`db:generate`, `db:migrate`, `db:studio`) so the config path and flags live in one place.

## `push` Is Not Migrations

`push` diffs your schema against the live database and applies the change immediately, leaving no artefact. That is genuinely the right tool for a local database you can drop, and the wrong tool for anything shared or deployed:

- **Local prototyping** → `push`, drop and re-push freely.
- **Anything committed, shared, or deployed** → `generate` + `migrate`, migration file reviewed in the PR.

Don't mix them against the same database. A `push` against a migrated database desynchronizes the snapshot, and the next `generate` produces a diff that makes no sense.

## `generate` Diffs Snapshots, Not the Database

The snapshots in `<out>/meta/` are the reference point, not the live schema. Two consequences:

- **Hand-edited databases drift silently.** A column added in a console is invisible to `generate` and will be re-added by the next migration. `pull` is the recovery path.
- **Parallel branches conflict.** Two branches that each generate `0004_` produce a duplicate-numbered pair that merges cleanly in git and breaks on apply. `drizzle-kit check` detects it; the fix is to regenerate on top of the merged schema, not to hand-renumber.

Commit `<out>/` — the SQL *and* `meta/`. Without the snapshots, the next `generate` re-diffs from nothing.

## Renames Prompt — Read the Prompt

`generate` cannot tell a rename from a drop-plus-create, so it asks. Answer wrong and the generated migration **drops the column and its data**. When the run is non-interactive (CI, an agent), that prompt is a blocker, not a warning — generate renames locally, review the SQL, then commit it.

Always read the generated SQL before committing. `generate` is a diffing tool, not a plan reviewer: it will happily emit a `DROP COLUMN` or a `NOT NULL` added to a table with existing rows.

Data migrations don't come out of `generate` at all. Add the SQL to the generated file by hand (or as a separate numbered migration) — a `NOT NULL` column added to a populated table needs a default or a backfill in the same migration.

## `casing`

Drizzle does not convert `camelCase` keys to `snake_case` columns by default. Two valid choices:

1. **Name every column explicitly** — `createdAt: timestamp('created_at')`. Verbose, obvious, no coupling.
2. **Set `casing: 'snake_case'`** in *both* `drizzle()` and `defineConfig()`.

Option 2's requirement is absolute: set it in one place only and the runtime queries and the migrations disagree about column names, which surfaces as "column does not exist" against a database the migrations just built. If you find it set in one place, that's a bug — fix it, don't work around it.

## D1

D1 migrations are applied by wrangler, not `drizzle-kit migrate`. See [`d1-workers.md`](d1-workers.md).
