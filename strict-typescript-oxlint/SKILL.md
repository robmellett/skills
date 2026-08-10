---
name: strict-typescript-oxlint
description: Write and configure strict TypeScript projects linted with Oxlint (no ESLint, no Prettier). Use when writing TypeScript code, setting up tsconfig.json or .oxlintrc.json, reviewing TS for type safety, or when the user mentions oxlint, strict mode, type-aware linting, or TypeScript conventions.
---

# Strict TypeScript + Oxlint

Conventions for all TypeScript work: strict compiler settings, Oxlint as the only linter, and explicit code-style rules. Never introduce ESLint or Prettier.

## Code style

- **If statements always use braces**, opening brace on the same line, space after the keyword:

  ```ts
  if (something) {
    doThing();
  }
  ```

  Never `if (x) return;` single-liners. Same applies to `else`, `for`, `while`. Enforced by `curly: ["error", "all"]`.
- No constant conditions: `if (true)`, `if (1)`, etc. are errors (`no-constant-condition`, a default correctness rule, pinned explicitly in the template). Intentional `while (true) {}` loops stay allowed via `checkLoops: "allow"`.
- `===`/`!==` only (`eqeqeq`).
- 2-space indent, semicolons, single quotes.

## Type conventions

- `interface` for object shapes that will be extended; `type` for unions, intersections, and mapped types.
- Never `any`. Use `unknown` and narrow with type guards; use `never` for exhaustive checks.
- No non-null assertions (`user!.profile`) — restructure or add a proper null check.
- Explicit checks for numbers/strings: `if (count !== undefined)`, not `if (count)` — truthy checks swallow `0` and `''`.
- Pick one nullability contract per boundary: `T | null` for API/DB responses, `?:` (undefined) for optional inputs. Don't mix.
- `as const` on literal arrays/objects meant for literal inference (`const ROLES = ['admin', 'user'] as const`).
- Export types alongside their implementations, not in separate type-only files.
- Discriminated unions for state machines; switch on the discriminant with a `never` default case for compile-time exhaustiveness.
- Runtime validation with Zod: define the schema, derive the type via `z.infer<typeof schema>` so runtime and compile-time never drift.
- Hono handlers: validate with `zValidator('json', schema)` and read via `c.req.valid('json')` — no manual casting. Catch errors, log internally, return safe error shapes (never leak internals).

## Project setup

Copy [templates/tsconfig.json](templates/tsconfig.json) and [templates/.oxlintrc.json](templates/.oxlintrc.json) into the project root.

```sh
pnpm add -D oxlint oxlint-tsgolint
```

package.json scripts:

```json
{
  "lint": "oxlint --type-aware",
  "lint:fix": "oxlint --type-aware --fix",
  "typecheck": "tsc --noEmit"
}
```

Notes:

- `oxlint-tsgolint` is required for type-aware rules (`typescript/no-floating-promises`, `typescript/await-thenable`, `typescript/strict-boolean-expressions`).
- Oxlint rule names drop the `@typescript-eslint/` prefix: it's `typescript/no-explicit-any`, not `@typescript-eslint/no-explicit-any`.
- `.oxlintrc.json` supports comments (JSONC). Nearest config to the linted file wins in monorepos — keep one at the workspace root and use `overrides` for per-package tweaks.
- `no-constant-condition` is on by default (correctness). It's pinned in the template so it survives any future relaxation of the correctness set; `checkLoops: "allow"` keeps intentional `while (true) {}` loops legal. Set `checkLoops: "all"` to flag constant loops too.

## Workflow

After writing or editing TypeScript, always run both:

```sh
pnpm typecheck && pnpm lint
```

Fix every error before presenting code. When reviewing existing code, check for: remaining `any`, missing null checks, unhandled error paths, truthy checks on numbers, and non-null assertions.
