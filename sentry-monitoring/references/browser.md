# Sentry — browser frontend (React + Vite)

`@sentry/react` (latest `10.x`) and `@sentry/vite-plugin` (`5.x`). For a non-React frontend, swap in `@sentry/browser` — the config below is otherwise identical.

## 1. Install

```bash
pnpm add @sentry/react
pnpm add -D @sentry/vite-plugin
```

## 2. Init before render

`src/main.tsx`, above the `createRoot` call — the SDK only captures what happens after `init`:

```ts
import * as Sentry from "@sentry/react";

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
  tracesSampleRate: 0.1,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  tracePropagationTargets: [/^\//, /^https:\/\/api\.yourdomain\.com/],
  sendDefaultPii: false,
});
```

`tracePropagationTargets` lists the origins that receive `sentry-trace` and `baggage` headers. Scope it to your own API: sending trace headers to a third-party host that doesn't allow them in CORS fails the request outright.

## 3. Catch render errors

Wrap the tree so a render-time throw becomes an event with component context rather than a blank screen:

```tsx
<Sentry.ErrorBoundary fallback={<p>Something went wrong.</p>}>
  <App />
</Sentry.ErrorBoundary>
```

## 4. Source maps

`vite.config.ts` — the Sentry plugin goes **last** so it sees the final output:

```ts
import { defineConfig } from "vite";
import { sentryVitePlugin } from "@sentry/vite-plugin";

export default defineConfig({
  build: {
    sourcemap: "hidden",
  },
  plugins: [
    // ...other plugins
    sentryVitePlugin({
      org: "<org-slug>",
      project: "<project-slug>",
      authToken: process.env.SENTRY_AUTH_TOKEN,
      sourcemaps: {
        filesToDeleteAfterUpload: ["./dist/**/*.map"],
      },
    }),
  ],
});
```

- `sourcemap: "hidden"` generates maps without the `//# sourceMappingURL` comment, so they upload to Sentry without being advertised to browsers.
- `filesToDeleteAfterUpload` removes them from the build output, keeping your source off the CDN.
- `SENTRY_AUTH_TOKEN` is a real credential: CI secret only. Locally it belongs in `.env.sentry-build-plugin`, which is gitignored.

## 5. DSN

```dotenv
# .env.local (gitignored); key mirrored empty in .env.example
VITE_SENTRY_DSN=
```

Any `VITE_`-prefixed var is inlined into the bundle and therefore public. That is correct for a DSN and wrong for anything else — never prefix the auth token.

## 6. Verify

```tsx
<button onClick={() => { throw new Error("Sentry install check"); }}>
  break
</button>
```

Run a production build (`pnpm build && pnpm preview`), click it, and confirm the event resolves to `.tsx` line numbers. Dev-mode events skip the source-map path entirely, so only a built bundle proves the upload works. Delete the button afterwards.
