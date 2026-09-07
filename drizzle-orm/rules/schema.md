# Schema

The schema file is the single source of truth: it defines the table, it is what `drizzle-kit` diffs to produce migrations, and it is what the static types are inferred from. Nothing about a table should be written down twice.

## Declare the Table, Infer the Types

Never hand-write a type that mirrors a table. Two exports, both derived:

```ts
export type User = typeof users.$inferSelect;   // a row you read
export type NewUser = typeof users.$inferInsert; // a row you write — defaults optional

// standalone equivalents, for when you only have the type
import type { InferSelectModel, InferInsertModel } from 'drizzle-orm';
type User2 = InferSelectModel<typeof users>;
```

`$inferInsert` is not `Partial<User>` — it knows which columns have defaults, which are generated, and which are genuinely required. That is the type function arguments and request bodies should take.

## Postgres

```ts
import {
  pgTable, pgEnum, integer, text, varchar, boolean, timestamp,
  jsonb, uuid, index, uniqueIndex, primaryKey, check,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

export const roleEnum = pgEnum('role', ['admin', 'editor', 'viewer']);

export const users = pgTable('users', {
  id: integer().generatedAlwaysAsIdentity().primaryKey(),
  // the column name defaults to the key — pass a string only to override it
  email: varchar('email_address', { length: 255 }).notNull().unique(),
  name: text().notNull(),
  role: roleEnum().default('viewer').notNull(),
  age: integer(),
  meta: jsonb().$type<{ plan: string }>().default({ plan: 'free' }),
  isActive: boolean('is_active').default(true).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp('updated_at').$onUpdate(() => new Date()),
}, (t) => [
  index('users_name_idx').on(t.name),
  check('age_positive', sql`${t.age} > 0`),
]);
```

The third argument **returns an array**. The older object form (`(t) => ({ nameIdx: index(...) })`) is deprecated — don't write it, and convert it when you touch a table that still uses it.

Prefer `.generatedAlwaysAsIdentity()` over `serial()` for new Postgres tables; `serial` is legacy and carries sequence-ownership surprises.

## Foreign Keys and Composite Keys

`references()` takes a thunk so tables can refer to each other in any order. Always state the delete behaviour — the database default is `no action`, which fails loudly later rather than never.

```ts
export const posts = pgTable('posts', {
  id: uuid().defaultRandom().primaryKey(),
  authorId: integer('author_id').notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  title: text().notNull(),
  publishedAt: timestamp('published_at'),
});

export const usersToGroups = pgTable('users_to_groups', {
  userId: integer('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  groupId: integer('group_id').notNull().references(() => groups.id, { onDelete: 'cascade' }),
}, (t) => [primaryKey({ columns: [t.userId, t.groupId] })]);
```

A join table gets a composite primary key, not a surrogate `id` — the pair *is* the identity, and the key enforces uniqueness for free.

## SQLite / D1

SQLite has no boolean, JSON, or timestamp type. The `mode` option owns the mapping in both directions — use it rather than converting at every call site.

```ts
import { sqliteTable, integer, text, real, index } from 'drizzle-orm/sqlite-core';
import { sql } from 'drizzle-orm';

export const users = sqliteTable('users', {
  id: integer().primaryKey({ autoIncrement: true }),
  email: text().notNull().unique(),
  isActive: integer('is_active', { mode: 'boolean' }).default(true).notNull(),
  prefs: text({ mode: 'json' }).$type<{ theme: string }>(),
  createdAt: integer('created_at', { mode: 'timestamp' })
    .default(sql`(unixepoch())`)
    .notNull(),
}, (t) => [index('users_email_idx').on(t.email)]);
```

Timestamps: `{ mode: 'timestamp' }` stores seconds, `'timestamp_ms'` stores milliseconds. Pick one per project and keep it — a mismatch is a silent 1000× date error, not a type error.

D1 is SQLite. Every rule here applies; the runtime differences are in [`d1-workers.md`](d1-workers.md).

## Column Helpers

Know which of these run in the database and which run in your process — it decides whether a row written by anything other than your app gets the value.

| Helper | Where it runs |
| --- | --- |
| `.default(value)`, ``.default(sql`now()`)`` | Database — in the DDL |
| `.$defaultFn(() => nanoid())` | App, on insert only |
| `.$onUpdate(() => new Date())` | App, on every update |
| `.$type<T>()` | Nowhere — narrows the TS type, emits no SQL |

`.$type<T>()` is an assertion. It is the right tool for a `jsonb`/`text({ mode: 'json' })` payload shape, and the wrong tool for anything the database could enforce with a real constraint.

Postgres arrays: `text().array()`, queried with `arrayContains` / `arrayOverlaps`.

## `unique()` vs `uniqueIndex()`

`.unique()` on the column emits a unique **constraint**; `uniqueIndex()` in the table's array emits a unique **index**. They enforce the same thing — pick one per column, not both, or the migration creates two redundant database objects. Reach for `uniqueIndex()` only when you need index-only features: a partial index (`.where(...)`) or an expression (``.on(sql`lower(${t.email})`)``).

## File Layout

Keep the schema a **single import graph**. One `schema.ts` is the default and stays fine well past the point people expect. If it must be split, split one table per file and re-export everything from a barrel — and declare relations centrally rather than per file (see [`relations.md`](relations.md)). Circular imports between schema files break `relations()` in ways the error message will not explain.

`drizzle.config.ts` points at these files, so a table that isn't in the configured `schema` glob is invisible to `drizzle-kit` — it silently won't get a migration.

## Validation Schemas with `drizzle-zod`

Derive request validation from the table rather than restating the columns in Zod.

```bash
pnpm add drizzle-zod
```

```ts
import { createInsertSchema, createSelectSchema, createUpdateSchema } from 'drizzle-zod';

export const insertUserSchema = createInsertSchema(users, {
  email: (s) => s.email(),        // refine the fields the database can't check
});
```

The generated schema mirrors database constraints only — nullability, lengths, enum members. Application rules (a real email, a minimum password length, a trimmed string) still have to be refined in. Pair with the Zod rules in the `zod-best-practices` skill.

Use `createInsertSchema` for `POST` bodies and `createUpdateSchema` for `PATCH` bodies — the latter makes every field optional, which is exactly the semantics of a partial update.
