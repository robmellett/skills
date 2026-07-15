---
name: zod-best-practices
description: "Apply this skill whenever writing, reviewing, or refactoring Zod (v4) schemas in TypeScript. Triggers on defining schemas, validating input, inferring types from schemas, parse vs safeParse, formatting Zod errors, composing or reusing schemas, discriminated unions, transforms, coercion, and branded types. Use especially when validating Hono requests — pairing Zod with @hono/zod-validator, c.req.valid, and shared client/server schemas. Also use for migrating v3 code to v4 and for Zod code review."
license: MIT
metadata:
  author: robmellett
  source: https://zod.dev
---

# Zod Best Practices

Best practices for **Zod v4** in TypeScript, organized as an index of rule files. Each rule teaches what to do and why. Zod's job is to be the **single source of truth**: the schema is the runtime validator *and* the origin of the static type — never write both by hand.

Zod pairs with **Hono**: define the schema once, validate the request with `@hono/zod-validator`, and infer the handler's types from the same schema. See [`rules/hono.md`](rules/hono.md).

## Version

This skill targets **Zod v4** (`zod` ≥ 3.25, imported as `import * as z from "zod"`). v4 is the default export of the `zod` package. Confirm the installed version before applying version-sensitive rules — check `package.json`. If the project is still on v3, the composition and type-inference rules hold, but the top-level format functions and error helpers below do not.

## Consistency First

Before applying any rule, check what the codebase already does. If schemas already live in a `schemas/` module, error handling already goes through one wrapper, or the project already picked `.parse()` vs `.safeParse()` at its boundaries — follow that. These rules are defaults for when no pattern exists yet, not overrides. Inconsistency is worse than a suboptimal pattern.

## How to Apply

1. Check sibling schemas, validators, and the project's Zod version for established patterns. Deviate only for a correctness defect, and call it out.
2. Map every affected concern to the rule index below. Read each mapped rule file before editing. Skip unrelated ones.
3. Keep the schema the single source of truth — derive types with `z.infer`, never redeclare them.
4. Make the smallest coherent change; don't introduce a second way to validate the same boundary.
5. Re-read the diff against every mapped rule before finishing.

## Rule Index

Cross-cutting changes often need more than one rule file.

| Concern | Read |
| --- | --- |
| Defining schemas, deriving types, coercion, strict/loose objects, v4 string formats | [`rules/schemas.md`](rules/schemas.md) |
| `parse` vs `safeParse`, boundary validation, formatting and customizing errors | [`rules/parsing.md`](rules/parsing.md) |
| Reusing and composing schemas, discriminated unions, transforms, refinements, branding | [`rules/composition.md`](rules/composition.md) |
| Validating Hono requests, shared client/server schemas, OpenAPI | [`rules/hono.md`](rules/hono.md) |

## Review Checklist

- Is any TypeScript `type`/`interface` duplicating a schema that could `z.infer` it instead?
- Does user input hit `.safeParse()` (or a validator that wraps it), never a bare `.parse()` that can crash the request?
- Are string formats written as top-level `z.email()` / `z.uuid()` / `z.url()`, not deprecated `z.string().email()`?
- Are objects `z.strictObject()` where unknown keys should be rejected, rather than silently stripped?
- Is coercion (`z.coerce`) used for query params and env vars where everything arrives as a string?
- Are errors surfaced through `z.treeifyError` / `z.flattenError` / `z.prettifyError`, not hand-walked?
