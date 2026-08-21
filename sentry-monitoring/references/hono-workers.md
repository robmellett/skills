# Sentry — Hono and Cloudflare Workers

`@sentry/hono` (latest `10.x`) for Hono apps; `@sentry/cloudflare` for a plain Worker. Both need the Cloudflare peer SDK.

## 1. Install

```bash
pnpm add @sentry/hono @sentry/cloudflare
```

For a Worker with no Hono app, `pnpm add @sentry/cloudflare` alone is enough.

## 2. wrangler.toml

```toml
compatibility_flags = ["nodejs_compat"]
upload_source_maps = true
```

`nodejs_compat` is required, not optional — the SDK builds its request scope on `AsyncLocalStorage`, which that flag provides. `upload_source_maps` makes `wrangler deploy` ship maps so traces resolve to your TypeScript instead of the bundle.

Keep `compatibility_date` at the project's current value (today's date on a fresh project).

## 3. Hono app

The middleware goes on before any route, so it wraps every handler:

```ts
import { Hono } from "hono";
import { sentry } from "@sentry/hono/cloudflare";

const app = new Hono<{ Bindings: Env }>();

app.use(
  sentry(app, (env) => ({
    dsn: env.SENTRY_DSN,
    environment: env.ENVIRONMENT,
    release: env.SENTRY_RELEASE,
    tracesSampleRate: 0.1,
    sendDefaultPii: false,
  })),
);

export default app;
```

Passing `app` is what lets the middleware hook the app's error handling. **A custom `app.onError` handles the error itself**, so capture inside it:

```ts
import * as Sentry from "@sentry/cloudflare";

app.onError((err, c) => {
  Sentry.captureException(err);

  return c.json({ error: "Internal Server Error" }, 500);
});
```

## 4. Plain Worker

```ts
import * as Sentry from "@sentry/cloudflare";

export default Sentry.withSentry(
  (env: Env) => ({
    dsn: env.SENTRY_DSN,
    tracesSampleRate: 0.1,
  }),
  {
    async fetch(request, env, ctx) {
      return new Response("ok");
    },
  } satisfies ExportedHandler<Env>,
);
```

## 5. DSN

Declare the secret in `wrangler.toml` so it lands on the generated `Env`:

```toml
[secrets]
required = ["SENTRY_DSN"]
```

```bash
pnpm exec wrangler types
```

Once `[secrets]` exists at any config level, `wrangler types` builds the typed binding from `secrets.required` and stops inferring names from `.dev.vars`. A secret declared in only some environments comes through as optional on the aggregated `Env`, so declare it in each environment you deploy.

Set the value per environment, and keep local dev in `.dev.vars` (gitignored):

```bash
pnpm exec wrangler secret put SENTRY_DSN
```

```dotenv
# .dev.vars
SENTRY_DSN=
ENVIRONMENT=local
```

Pick `.dev.vars` **or** `.env` for local values — Wrangler loads one or the other, not both.

## 6. Verify

Add a throwaway route, hit it, confirm the event in Sentry, then delete the route:

```ts
app.get("/debug-sentry", () => {
  throw new Error("Sentry install check");
});
```

```bash
pnpm dev
curl http://localhost:8787/debug-sentry
```

An event with a resolved TypeScript stack frame is the completion criterion. A frame pointing into bundled output means source maps aren't landing — check `upload_source_maps`.

## 7. Release from CI

Sentry reads the `SENTRY_RELEASE` var automatically. Set it in `wrangler.toml`'s `[vars]` per environment, or pass it at deploy time from the workflow's `github.sha`.
