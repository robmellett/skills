# Parsing & Errors Best Practices

## `safeParse` at Trust Boundaries, `parse` for Invariants

`.parse()` **throws** a `ZodError` on failure. `.safeParse()` returns `{ success, data }` or `{ success, error }` and never throws. Choose by whether failure is *expected*:

- **User input, network responses, webhooks, query params** → `.safeParse()`. Invalid input is a normal 400, not a crash.
- **Config and env loaded once at startup** → `.parse()` is fine; a bad config *should* crash the process loudly.

Incorrect — a malformed body takes down the request:
```ts
const data = userSchema.parse(await req.json()); // throws → 500
```

Correct:
```ts
const result = userSchema.safeParse(await req.json());
if (!result.success) {
  return Response.json(z.flattenError(result.error), { status: 400 });
}
const data = result.data;
```

> In Hono, don't hand-roll this — `zValidator` wraps `safeParse` for you. See [`hono.md`](hono.md).

## Read Issues from `.error.issues`

On a failed `safeParse`, the raw array is `result.error.issues` (v4). Don't reach for the deprecated `.errors`.

## Format Errors with the Top-Level Helpers

Don't walk the error tree by hand. Zod v4 provides three shapes; pick by consumer:

```ts
z.treeifyError(result.error);   // nested object mirroring the schema — for structured API responses
z.flattenError(result.error);   // { formErrors, fieldErrors } — for simple/flat forms
z.prettifyError(result.error);  // human-readable multiline string — for logs and CLIs
```

The v3 `.format()` method is deprecated in favor of `z.treeifyError()`.

## Customize Messages with the `error` Param (v4)

Zod v4 folds v3's `message`, `invalid_type_error`, `required_error`, and `errorMap` into a single `error` parameter. It accepts a string or a function.

```ts
z.string({ error: "Name is required" });

z.string().min(3, { error: "Must be at least 3 characters" });

// Function form for conditional messages
z.string({
  error: (issue) =>
    issue.input === undefined ? "Required" : "Must be a string",
});
```

## Set a Global Error Map Once

For app-wide message conventions (e.g. i18n), register a global error map instead of repeating `error` on every field.

```ts
z.config({
  customError: (issue) => {
    if (issue.code === "too_small") return "Value is too short";
  },
});
```
