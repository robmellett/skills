# Queries

`db.select()` is a typed spelling of SQL. Read it as SQL, and the result type follows the shape you asked for.

## Select the Columns You Need

`db.select()` with no argument is `SELECT *`. Pass an object and the return type narrows to match — which is both a payload win and a documentation win at the call site.

```ts
await db.select().from(users);                                  // full rows
await db.select({ id: users.id, name: users.name }).from(users); // { id, name }[]

await db.select({
  id: users.id,
  display: sql<string>`upper(${users.name})`.as('display'),
}).from(users);

await db.select().from(users).orderBy(desc(users.createdAt)).limit(20).offset(40);
```

**`select()` always resolves to an array.** For one row, destructure or use `findFirst` — never index into it and assume:

```ts
const [user] = await db.select().from(users).where(eq(users.id, id)).limit(1);
if (!user) return c.json({ error: 'Not found' }, 404);
```

On SQLite/D1 the builder also exposes `.get()` (first row or `undefined`) and `.all()`.

## Filter Operators

All import from `drizzle-orm`:

```
eq  ne  gt  gte  lt  lte
isNull  isNotNull  inArray  notInArray  between  notBetween
like  notLike  ilike  notIlike            (ilike is Postgres-only)
and  or  not  exists  notExists
arrayContains  arrayContained  arrayOverlaps    (Postgres arrays)
```

```ts
import { and, or, eq, gt, ilike, inArray, desc } from 'drizzle-orm';

await db.select().from(users).where(
  and(
    eq(users.isActive, true),
    or(gt(users.age, 18), ilike(users.name, '%rob%')),
    inArray(users.role, ['admin', 'editor']),
  ),
);
```

`inArray` with an empty array is a SQL error on some dialects — guard it (`ids.length ? inArray(...) : undefined`).

## Conditional Filters: Pass `undefined`

`and()` and `or()` drop `undefined` entries. That is the idiom for optional filters — no builder reassignment, no string concatenation:

```ts
const rows = await db.select().from(posts).where(
  and(
    term ? ilike(posts.title, `%${term}%`) : undefined,
    tags.length ? inArray(posts.tag, tags) : undefined,
    authorId ? eq(posts.authorId, authorId) : undefined,
  ),
);
```

For a longer list, accumulate then spread:

```ts
const filters: SQL[] = [];
if (term) filters.push(ilike(posts.title, `%${term}%`));
await db.select().from(posts).where(and(...filters));
```

`and()` of nothing is `undefined`, which means "no `WHERE`" — fine for a list endpoint, dangerous if the same helper ever feeds an `update` or `delete`.

## Aggregates and Grouping

```ts
import { count, countDistinct, sum, avg, min, max, gt } from 'drizzle-orm';

await db
  .select({ authorId: posts.authorId, total: count() })
  .from(posts)
  .groupBy(posts.authorId)
  .having(({ total }) => gt(total, 5));
```

For a plain row count, `$count` returns a **number**, not a row array:

```ts
const total = await db.$count(posts, eq(posts.authorId, authorId));
```

Postgres `count(*)` in a raw fragment comes back as a **string** — `sql<number>` is an assertion, not a conversion. Either use `count()` or cast: ``sql<number>`count(*)::int` ``.

## Joins

```ts
await db
  .select({ post: posts, authorName: users.name })
  .from(posts)
  .innerJoin(users, eq(posts.authorId, users.id));
```

`innerJoin`, `leftJoin`, `rightJoin`, `fullJoin`, `crossJoin`. With `leftJoin` the joined side is **nullable in the result type** — Drizzle tells you the truth, so handle the `null` rather than asserting it away.

Nesting a whole table (`{ post: posts }`) groups its columns under that key in the result. Selecting the same table twice needs `alias`:

```ts
import { alias } from 'drizzle-orm/pg-core';
const manager = alias(users, 'manager');
await db.select().from(users).leftJoin(manager, eq(users.managerId, manager.id));
```

Joins return flat, duplicated rows — one per matched pair. When you want a nested object graph instead, that's [`relations.md`](relations.md).

## Dynamic Query Building

The builder's types deliberately stop you calling `.where()` twice. `.$dynamic()` opts out so a query can be assembled in stages or passed to a helper:

```ts
function paginate<T extends PgSelect>(qb: T, page: number, size = 20) {
  return qb.limit(size).offset(page * size);
}

let query = db.select().from(users).$dynamic();
if (activeOnly) query = query.where(eq(users.isActive, true));
const rows = await paginate(query, page);
```

Reach for this only for genuinely reusable builder helpers. For optional filters, the `undefined` idiom above is simpler and keeps the static types.

## Raw SQL

```ts
import { sql } from 'drizzle-orm';

// interpolated values become bound parameters; column refs are escaped
await db.select().from(users).where(sql`lower(${users.email}) = ${email.toLowerCase()}`);

await db.select({ total: sql<number>`count(*)::int` }).from(users);

await db.execute(sql`select now()`);        // pg
await db.all(sql`select * from users`);     // sqlite / d1
```

``sql`…` `` binds its interpolations — it is safe with user input and is the right escape hatch for a function or operator Drizzle doesn't wrap.

`sql.raw()` does **not** bind. It exists for identifiers you control (a table name from a constant, a generated `ORDER BY` direction) and never for a value that came from a request. If you're reaching for it, `sql.identifier(name)` or ``sql.join(fragments, sql`, `)`` usually says what you meant.

## Prepared Statements

Worth it in hot paths — skips query building and SQL generation per call:

```ts
const byId = db.select().from(users)
  .where(eq(users.id, sql.placeholder('id')))
  .prepare('users_by_id');   // the name is required on Postgres

await byId.execute({ id: 1 });
```

A prepared statement must be built once and reused, so it belongs at module scope — which makes it a poor fit for D1, where the client itself is per-request ([`d1-workers.md`](d1-workers.md)).

## See the SQL

Pass `{ logger: true }` to `drizzle()` to print every generated statement, or call `.toSQL()` on a builder to inspect the query and its params without running it. When a query returns the wrong rows, read the SQL before rewriting the TypeScript.
