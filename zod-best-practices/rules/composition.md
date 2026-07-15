# Composition & Refinement Best Practices

## Compose, Don't Repeat

Build large schemas from small ones. Derive variants with `.extend`, `.pick`, `.omit`, and `.partial` instead of redeclaring fields.

```ts
const userSchema = z.object({
  id: z.uuid(),
  email: z.email(),
  name: z.string(),
  createdAt: z.date(),
});

// Request body: everything the client supplies, nothing server-owned
const createUserSchema = userSchema.omit({ id: true, createdAt: true });

// Update: same fields, all optional
const updateUserSchema = createUserSchema.partial();

// Public view: drop sensitive-adjacent fields, keep the rest
const publicUserSchema = userSchema.pick({ id: true, name: true });
```

This keeps one authoritative shape; a new field added to `userSchema` flows into every derived schema automatically.

## Discriminated Unions for Tagged Shapes

When a shared literal field selects the variant, use `z.discriminatedUnion`. It parses faster and produces far clearer errors than a plain `z.union` because Zod checks the discriminator first instead of trying every member.

```ts
const event = z.discriminatedUnion("type", [
  z.object({ type: z.literal("click"), x: z.number(), y: z.number() }),
  z.object({ type: z.literal("submit"), formId: z.string() }),
]);
```

## `refine` / `check` for Cross-Field Rules

Field-level validators can't see other fields. Use `.refine()` (single rule) or `.check()` / `.superRefine()` (multiple issues, precise paths) for cross-field constraints.

```ts
const signup = z
  .object({
    password: z.string().min(8),
    confirm: z.string(),
  })
  .refine((data) => data.password === data.confirm, {
    error: "Passwords do not match",
    path: ["confirm"], // attach the error to the right field
  });
```

## `transform` and `pipe` to Reshape After Validation

Validate, then transform. Use `.transform()` to change the parsed value, and `.pipe()` to feed one schema's output into another for a second validation pass.

```ts
const slug = z
  .string()
  .transform((s) => s.trim().toLowerCase())
  .pipe(z.string().regex(/^[a-z0-9-]+$/));
```

Remember transforms make `z.input` and `z.output` diverge — type accordingly (see [`schemas.md`](schemas.md)).

## Brand Nominal Types

When two `string` schemas mean different things (a `UserId` vs a raw string), `.brand()` makes them non-interchangeable at compile time without any runtime cost.

```ts
const UserId = z.uuid().brand<"UserId">();
type UserId = z.infer<typeof UserId>; // string & { __brand: "UserId" }
```

## `z.lazy` for Recursion

Self-referential schemas need `z.lazy` to defer evaluation.

```ts
const category = z.object({
  name: z.string(),
  get subcategories() {
    return z.array(category); // v4 getter form, or z.lazy(() => z.array(category))
  },
});
```
