# Drizzle on Cloudflare D1 and Workers

D1 is SQLite, so [`schema.md`](schema.md)'s SQLite rules apply as written. What's different is the runtime: the database arrives as a **binding on the request's `env`**, not as a connection string.

## Build the Client Per Request

`env` is only available inside the handler, so the client is built per request — never at module scope.

```ts
// src/db/index.ts
import { drizzle } from 'drizzle-orm/d1';
import * as schema from './schema';

export function createDb(d1: D1Database) {
  return drizzle(d1, { schema });
}
export type Db = ReturnType<typeof createDb>;
```

The factory is cheap — it wraps the binding, it doesn't open a connection, so there is nothing to pool or reuse. A module-scope client can't be built anyway: `env` isn't available at the top level of a Worker, and a client captured from one request outlives that request in a reused isolate.

Take `D1Database` or `Db` as a parameter in every function that touches the database, rather than reaching into `c.env` inside it. That is what makes the data layer testable without a Worker.

## Wire It Into Hono

Put the client on the context in one middleware, and type it so handlers get it for free:

```ts
import { Hono } from 'hono';
import { createDb, type Db } from './db';

const app = new Hono<{ Bindings: Env; Variables: { db: Db } }>();

app.use('*', async (c, next) => {
  c.set('db', createDb(c.env.DB));
  await next();
});

app.get('/users', async (c) => {
  const rows = await c.var.db.select().from(users);
  return c.json(rows);
});
```

`Env` comes from `wrangler types` — don't hand-write it.

## `batch`, Not `transaction`

**D1 has no interactive transactions**, so `db.transaction()` is not an atomic boundary there regardless of how it behaves at runtime. Use `db.batch([...])`, which ships the statements together and applies them atomically. The constraint and the workaround are in [`writes.md`](writes.md).

Practically: generate ids in the app (`crypto.randomUUID()` via `.$defaultFn()`) so a batch never needs the previous statement's output.

## Migrations: drizzle-kit Generates, wrangler Applies

`drizzle-kit` produces the SQL; wrangler owns applying it, because it tracks applied migrations in the D1 database itself. Point wrangler at drizzle's output directory:

```toml
# wrangler.toml
[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "..."
migrations_dir = "drizzle"
```

```ts
// drizzle.config.ts — kit talks to D1 over HTTP; the Worker still uses the binding
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  dialect: 'sqlite',
  driver: 'd1-http',
  schema: './src/db/schema.ts',
  out: './drizzle',
  dbCredentials: {
    accountId: process.env.CLOUDFLARE_ACCOUNT_ID!,
    databaseId: process.env.CLOUDFLARE_DATABASE_ID!,
    token: process.env.CLOUDFLARE_D1_TOKEN!,   // needs the D1:Edit permission
  },
});
```

```bash
pnpm drizzle-kit generate --name add_posts_table
pnpm exec wrangler d1 migrations apply my-db --local
pnpm exec wrangler d1 migrations apply my-db --remote
```

Never `drizzle-kit migrate` against D1 — the two tools keep separate ledgers of what's applied, and running both leaves the database in a state neither believes in. `drizzle-kit push` has the same problem; it's only defensible against a local `--local` database you're happy to delete.

The `d1-http` credentials are only needed for kit features that read the remote database (`pull`, `studio`, `check` against remote). Plain `generate` diffs snapshots and needs no credentials at all.

## Testing

Run tests in the Workers pool, apply the drizzle migrations into the test D1, and construct the client from the test `env`:

```ts
// test/setup.ts — Node side, reads the files
import { readD1Migrations } from '@cloudflare/vitest-pool-workers/config';
export const migrations = await readD1Migrations('./drizzle');
```

```ts
// test/users.test.ts
import { env, exports } from 'cloudflare:workers';
import { applyD1Migrations } from 'cloudflare:test';
import { beforeAll, expect, it } from 'vitest';
import { createDb } from '../src/db';
import { migrations } from './setup';

beforeAll(async () => {
  await applyD1Migrations(env.DB, migrations);
});

it('creates a user', async () => {
  const db = createDb(env.DB);
  const [user] = await db.insert(users).values({ email: 'a@b.com' }).returning();
  expect(user.email).toBe('a@b.com');
});

it('serves them over HTTP', async () => {
  const res = await exports.default.fetch(new Request('http://x/users'));
  expect(res.status).toBe(200);
});
```

Test the data functions directly against `env.DB` — that's the fast path and where the query assertions belong. Reserve `exports.default.fetch()` for asserting the HTTP contract: status, shape, validation errors.

Because `createDb` takes the binding as a parameter, no mocking is involved anywhere — the tests run against real D1 in `workerd`.
