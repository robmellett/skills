# Zod + Hono Best Practices

Zod is Hono's default validation layer. The pairing works because both sides share one schema: `@hono/zod-validator` runs `safeParse` as middleware, and the handler infers its types from the same schema — no manual casting, no duplicated types.

```bash
pnpm add zod @hono/zod-validator
```

## Validate with `zValidator`, Read with `c.req.valid`

Put `zValidator(target, schema)` in the middleware chain and pull the parsed, typed value out with `c.req.valid(target)`. Never call `c.req.json()` and parse by hand — that discards the type inference and the automatic 400.

```ts
import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import * as z from "zod";

const createUser = z.object({
  name: z.string().min(1),
  email: z.email(),
});

app.post("/users", zValidator("json", createUser), (c) => {
  const data = c.req.valid("json"); // typed { name: string; email: string }
  return c.json(data, 201);
});
```

## Match the Target to the Source

`zValidator`'s first argument selects where the data comes from. Coerce for the string-based targets (see [`schemas.md`](schemas.md)).

| Target | Source |
| --- | --- |
| `"json"` | JSON request body |
| `"form"` | `multipart/form-data` or urlencoded body |
| `"query"` | URL query string — values are strings, use `z.coerce` |
| `"param"` | path params — strings, use `z.coerce` |
| `"header"` | request headers |
| `"cookie"` | cookies |

```ts
const listQuery = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().max(100).default(20),
});

app.get("/users", zValidator("query", listQuery), (c) => {
  const { page, limit } = c.req.valid("query"); // numbers, defaulted
  // ...
});
```

## Centralize Error Handling in One Wrapper

By default `zValidator` returns a raw `ZodError` as a 400 — inconsistent with the rest of your API's error shape. Wrap it once with a hook so every validated route fails the same way, then import your wrapper everywhere instead of the raw one.

```ts
// lib/validator.ts
import { zValidator as zv } from "@hono/zod-validator";
import type { ValidationTargets } from "hono";
import * as z from "zod";

export const zValidator = <T extends z.ZodType, Target extends keyof ValidationTargets>(
  target: Target,
  schema: T,
) =>
  zv(target, schema, (result, c) => {
    if (!result.success) {
      return c.json(
        { error: "Validation failed", issues: z.flattenError(result.error).fieldErrors },
        400,
      );
    }
  });
```

Prefer this hook over a bare `throw new HTTPException` when the client needs the field-level detail; throw only when you deliberately want to hide it.

## Share Schemas Across the Stack

The same schema module can back the server validator, the inferred type, and the client. With Hono's RPC (`hono/client`), request and response types flow to the frontend automatically when routes are validated with `zValidator` — so a schema change surfaces as a client-side type error, not a runtime surprise.

Keep schemas in a shared module (e.g. `src/schemas/`) imported by both handler and client, rather than redefining them per layer.

## Reach for `@hono/zod-openapi` When You Need a Spec

If the API must publish OpenAPI docs, use `@hono/zod-openapi`: you define routes with Zod schemas and get validation *and* a generated OpenAPI document from the single source. Don't hand-maintain a separate spec alongside the schemas.
