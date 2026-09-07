# Relations and Nested Reads

Two ways to read across tables, and they answer different questions:

- **`db.select()` + joins** — a flat, SQL-shaped result set, one row per matched pair. Right for aggregates, reports, and filtering a parent by a child's column.
- **`db.query.*` with `with`** — a nested object graph, one round trip. Right for anything you're about to serialize into a JSON response.

Reach for `db.query` when the response is nested; reach for joins when the answer is a table.

## Declare the Relations

`relations()` is app-level metadata for the query API. It emits **no SQL** — the foreign key in the schema is what the database enforces ([`schema.md`](schema.md)), and these two must agree by hand.

```ts
import { relations } from 'drizzle-orm';

export const usersRelations = relations(users, ({ many, one }) => ({
  posts: many(posts),
  profile: one(profiles),
}));

export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, { fields: [posts.authorId], references: [users.id] }),
}));
```

The `one` side carries `fields`/`references`; the `many` side infers them. On 0.4x **both directions must be declared** for either to work.

Then pass the schema to the client — `db.query` does not exist without it:

```ts
import * as schema from './schema';
const db = drizzle(client, { schema });
```

Export the relations from the same barrel as the tables so `import * as schema` picks them up.

## `findMany` / `findFirst`

```ts
const result = await db.query.users.findMany({
  columns: { id: true, name: true },        // or { password: false } to exclude
  with: {
    posts: {
      columns: { title: true },
      where: (posts, { isNotNull }) => isNotNull(posts.publishedAt),
      orderBy: (posts, { desc }) => desc(posts.publishedAt),
      limit: 5,
    },
  },
  where: (users, { eq }) => eq(users.isActive, true),
  orderBy: (users, { asc }) => asc(users.name),
  extras: { slug: sql<string>`lower(${users.name})`.as('slug') },
  limit: 20,
});

const user = await db.query.users.findFirst({ where: eq(users.id, id) });
```

`columns` is all-include or all-exclude — mixing `true` and `false` keys in one object is a mistake. `findMany` returns `[]`; `findFirst` returns `undefined` — check it, don't assert it.

`limit` inside `with` limits per parent, which is what pagination of a child collection actually needs.

## No Lazy Loading, By Design

A relation you didn't ask for in `with` is simply **absent** from the result — not `undefined`, not a lazy proxy. That is why N+1 doesn't happen by accident in Drizzle: there is nothing to trigger. The N+1 you can still write is the manual one — a `db.select()` per row of a previous result:

```ts
// N+1 — one query per user
for (const u of usersList) {
  u.posts = await db.select().from(posts).where(eq(posts.authorId, u.id));
}

// one round trip
const usersList = await db.query.users.findMany({ with: { posts: true } });
```

If a nested read is genuinely hot, check `{ logger: true }` output — the query API may emit a lateral join or a subquery depending on dialect, and the fix is usually a join query, not a loop.

## Many-to-Many

On 0.4x you traverse the junction table explicitly, dropping its own columns with `columns: {}`:

```ts
await db.query.users.findMany({
  with: {
    usersToGroups: {
      columns: {},
      with: { group: true },
    },
  },
});
```

The result nests one level deeper than the domain shape (`user.usersToGroups[].group`), so flatten it in the mapper rather than leaking the join table into your API response. v1's `.through()` collapses this into a single declaration — [`v1.md`](v1.md).

## Filtering a Parent by a Child

`db.query`'s `where` only sees the parent's own columns. To filter parents by a child's column, use a join or an `exists` subquery:

```ts
import { exists, and, eq, isNotNull } from 'drizzle-orm';

await db.select().from(users).where(
  exists(
    db.select().from(posts).where(
      and(eq(posts.authorId, users.id), isNotNull(posts.publishedAt)),
    ),
  ),
);
```

Filtering inside `with` filters the *children*, not the parents — parents with no matching children still come back, with an empty array. That distinction is the single most common `db.query` bug.
