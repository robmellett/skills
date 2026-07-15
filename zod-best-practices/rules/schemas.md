# Schemas & Types Best Practices

## The Schema Is the Single Source of Truth

Define the schema, then derive the type from it. Never maintain a hand-written `interface` alongside a schema that validates the same shape — they drift.

Incorrect:
```ts
interface User {
  id: string;
  email: string;
}

const userSchema = z.object({
  id: z.uuid(),
  email: z.email(),
});
```

Correct:
```ts
const userSchema = z.object({
  id: z.uuid(),
  email: z.email(),
});

type User = z.infer<typeof userSchema>;
```

## Use `z.input` and `z.output` When Transforms Are Involved

`z.infer` equals `z.output`. When a schema coerces or transforms, the type *before* parsing differs from the type *after*. Use `z.input` for the pre-parse shape (e.g. what a caller sends) and `z.output`/`z.infer` for the parsed result.

```ts
const schema = z.object({
  count: z.coerce.number(), // input: unknown/string → output: number
});

type In = z.input<typeof schema>;   // { count: unknown }
type Out = z.output<typeof schema>; // { count: number }
```

## Prefer Top-Level Format Functions (v4)

Zod v4 moved string formats to top-level functions. The chained forms (`z.string().email()`) are deprecated. Use the top-level versions in new code.

```ts
z.email();
z.uuid();
z.url();
z.iso.datetime();
z.iso.date();
```

Not `z.string().email()`, `z.string().uuid()`, etc.

## Reject Unknown Keys with `z.strictObject`

A plain `z.object()` **strips** unknown keys silently. When an unexpected key should be an error (API request bodies, config), use `z.strictObject()`. Use `z.looseObject()` to keep unknown keys. Prefer these top-level forms over the deprecated `.strict()` / `.passthrough()` methods.

```ts
// Rejects { name, role } if `role` isn't declared
const body = z.strictObject({ name: z.string() });
```

## Coerce at String Boundaries

Query params, path params, environment variables, and form fields all arrive as strings. Use `z.coerce` so the schema does the conversion instead of the handler.

```ts
const envSchema = z.object({
  PORT: z.coerce.number().int().positive(),
  DEBUG: z.stringbool(), // "true"/"1"/"yes" → boolean
});

const env = envSchema.parse(process.env);
```

## `optional` vs `nullable` vs `default`

These are distinct — pick deliberately:

- `.optional()` — the key may be absent (`T | undefined`).
- `.nullable()` — the value may be `null` (`T | null`).
- `.default(v)` — absent/`undefined` input becomes `v`; the output type is never undefined.

```ts
z.object({
  nickname: z.string().optional(),        // may be missing
  deletedAt: z.date().nullable(),         // present but nullable
  role: z.enum(["user", "admin"]).default("user"),
});
```

## Prefer `z.enum` over Unions of Literals

```ts
// Preferred
const role = z.enum(["user", "admin", "owner"]);

// Avoid — verbose, no .enum accessor
const role = z.union([z.literal("user"), z.literal("admin"), z.literal("owner")]);
```
