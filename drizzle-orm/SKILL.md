---
name: drizzle-orm
description: "Apply this skill whenever writing, reviewing, or refactoring Drizzle ORM code in TypeScript. Triggers on defining tables and columns in pgTable/sqliteTable/mysqlTable, inferring types from a schema, building selects with eq/and/inArray, joins, aggregates, dynamic query building, insert/upsert/update/delete, transactions vs batch, relational queries via db.query and relations(), drizzle.config.ts, drizzle-kit generate/migrate/push/pull, and drizzle-zod. Use especially for Drizzle on Cloudflare D1 and Workers — per-request clients, wrangler migrations, and testing with the Workers pool. Also use for migrating 0.4x code to v1 and for Drizzle code review."
license: MIT
metadata:
  author: robmellett
  source: https://orm.drizzle.team
---

# Drizzle ORM

Best practices for **Drizzle ORM** in TypeScript, organized as an index of rule files. Drizzle is not an abstraction over SQL — it is a typed spelling of it. Every rule here follows from that: the query builder mirrors the SQL you'd write, and the **schema is the single source of truth** for the table, the migration, and the static types.

Drizzle is the data layer of the Cloudflare stack — **Hono** handlers on **Workers** talking to **D1**. See [`rules/d1-workers.md`](rules/d1-workers.md).

## Version

Baseline is **`drizzle-orm` 0.4x / `drizzle-kit` 0.3x**. Read `package.json` before applying anything version-sensitive; the relations API and the `casing` option are the two places 0.4x and v1 genuinely diverge.

- On 0.4x — per-table `relations()`, `drizzle(client, { schema })`.
- On v1 (`1.x`, or `@beta` while it is unreleased) — one `defineRelations()` file, `drizzle(client, { relations })`. Read [`rules/v1.md`](rules/v1.md).

Everything else in this skill — schema, selects, writes, migrations — holds on both.

## Consistency First

Check what the codebase already does before applying any rule. If tables already live one-per-file, if the project already picked `push` for dev and `generate` for deploy, if column names are already spelled explicitly rather than via `casing` — follow that. These rules are defaults for greenfield decisions, not licence to convert a working schema. A mixed schema is worse than a uniformly suboptimal one.

## How to Apply

1. Read the existing schema file(s), `drizzle.config.ts`, and the installed versions. Deviate from established patterns only for a correctness defect, and say so.
2. Map every affected concern to the rule index below. Read each mapped rule file before editing. Skip unrelated ones.
3. Keep the schema the single source of truth — derive types with `$inferSelect` / `$inferInsert`, never hand-write a matching `interface`.
4. Make the smallest coherent change. Don't add a second way to reach the same table.
5. When the change touches a table's shape, generate the migration in the same change — a schema edit without a migration is an incomplete change.
6. Re-read the diff against every mapped rule before finishing.

## Rule Index

Cross-cutting changes often need more than one rule file.

| Concern | Read |
| --- | --- |
| Tables, columns, enums, indexes, constraints, dialect differences, inferred types, `drizzle-zod` | [`rules/schema.md`](rules/schema.md) |
| `select`, filter operators, conditional filters, joins, aggregates, `$dynamic()`, prepared statements, raw `sql` | [`rules/queries.md`](rules/queries.md) |
| `insert`, upsert, `update`, `delete`, `returning`, transactions, `batch` | [`rules/writes.md`](rules/writes.md) |
| Nested reads with `db.query`, `relations()`, many-to-many, avoiding N+1 | [`rules/relations.md`](rules/relations.md) |
| `drizzle.config.ts`, `drizzle-kit` commands, `push` vs `generate`, renames, drift | [`rules/migrations.md`](rules/migrations.md) |
| Cloudflare D1, Workers, Hono wiring, wrangler migrations, testing | [`rules/d1-workers.md`](rules/d1-workers.md) |
| Migrating 0.4x → v1, `defineRelations` | [`rules/v1.md`](rules/v1.md) |

## Review Checklist

- Is any `interface` or `type` restating a table that `$inferSelect` / `$inferInsert` could derive?
- Does every `update` and `delete` carry a `.where()`? An unfiltered one rewrites the whole table silently.
- Is a `select()` result destructured (`const [row] = …`) or `.limit(1)`-ed where a single row is expected — rather than treated as if it were the row?
- Do nested reads go through one `db.query` with `with`, rather than a loop of queries per parent row?
- Is user input interpolated into ``sql`…` `` (bound) rather than `sql.raw()` (not bound)?
- On D1: is the client built per request from the binding, and are multi-statement writes `db.batch([...])` rather than `db.transaction()`?
- Does a schema change in this diff have its generated migration alongside it?
- Is `casing` either absent (columns named explicitly) or set identically in both `drizzle()` and `defineConfig()`?
