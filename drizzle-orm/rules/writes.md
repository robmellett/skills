# Writes

## Insert

```ts
await db.insert(users).values({ email: 'a@b.com', name: 'Rob' });

// bulk — one statement, not a loop
await db.insert(users).values(rows);
```

Never loop `await db.insert(...)` over an array. One `values(rows)` call is a single round trip; a loop is N.

`returning()` (Postgres and SQLite/D1; **not** MySQL) saves the follow-up read:

```ts
const [user] = await db.insert(users).values(input).returning();
const [{ id }] = await db.insert(users).values(input).returning({ id: users.id });
```

Type the input as `typeof users.$inferInsert` so defaults stay optional and required columns stay required.

## Upsert

```ts
// Postgres / SQLite / D1
await db.insert(users)
  .values({ email: 'a@b.com', name: 'Rob' })
  .onConflictDoUpdate({
    target: users.email,
    set: { name: sql`excluded.name` },
  });

await db.insert(users).values(input).onConflictDoNothing({ target: users.email });

// MySQL
await db.insert(users).values(input).onDuplicateKeyUpdate({ set: { name: 'Rob' } });
```

`excluded.<col>` is the row that was proposed — use it to write "take the new value" without repeating the input in `set`. `target` must match an actual unique constraint or index, or the statement errors at runtime rather than compile time. For a partial unique index, pass `targetWhere`; to make the update itself conditional, `setWhere`.

Upsert is the correct shape for sync and idempotent-ingest work; a read-then-insert is a race.

## Update and Delete

```ts
await db.update(users).set({ name: 'Rob' }).where(eq(users.id, id));

await db.update(posts)
  .set({ views: sql`${posts.views} + 1` })
  .where(eq(posts.id, id))
  .returning();

await db.delete(users).where(eq(users.id, id));
```

**Always attach a `.where()`.** An unfiltered `update` or `delete` is valid SQL that rewrites or empties the entire table, and Drizzle has no guard rail. When the filter is built dynamically, assert it exists before running the statement:

```ts
const filter = and(...filters);
if (!filter) throw new Error('refusing to update every row');
await db.update(users).set(patch).where(filter);
```

Increment and other read-modify-write updates belong in SQL (``sql`${posts.views} + 1` ``), not in application code — fetching, adding one, and writing back loses concurrent updates.

Prefer a soft delete (`deletedAt`) or `onDelete: 'cascade'` on the foreign key over hand-deleting children in sequence.

## Transactions

```ts
await db.transaction(async (tx) => {
  const [user] = await tx.insert(users).values(input).returning();
  await tx.insert(posts).values({ authorId: user.id, title: 'Hi' });
  // throw to roll back, or call tx.rollback()
});

await db.transaction(async (tx) => { /* … */ }, { isolationLevel: 'serializable' });
```

Every statement inside must use `tx`, not `db` — a stray `db` call escapes the transaction and won't roll back. Keep the callback to database work only: no `fetch`, no queue publish, no email. Side effects don't roll back, and they hold the transaction open while they wait.

The callback's return value is the return value of `db.transaction(...)`.

## Batch — When Transactions Aren't Available

HTTP-based drivers, **Cloudflare D1 included**, have no interactive transactions. `batch` sends the statements together and applies them atomically:

```ts
const [inserted, all] = await db.batch([
  db.insert(users).values(input).returning({ id: users.id }),
  db.select().from(users),
]);
```

The result tuple is typed positionally, matching the array. The constraint: **no statement can depend on another's result**, since the whole array is built before anything runs. When you need a generated id in the next statement, either generate it in the app (`.$defaultFn(() => crypto.randomUUID())` — see [`schema.md`](schema.md)) so it's known up front, or accept two round trips and design for the failure between them.

Statements passed to `batch` must not be awaited individually — hand the builders in unawaited.
