---
name: sentry-monitoring
description: >
  Wire Sentry into a project — errors, tracing, releases, source maps. Use when
  adding Sentry to a Laravel app, a Hono/Cloudflare Workers app, or a Vite
  browser frontend; when a project is being scaffolded and needs monitoring;
  when a DSN, source-map upload, or release marker is being configured; or when
  sample rates are set or changed. Triggers on add sentry, sentry dsn, error
  tracking, error monitoring, crash reporting, traces sample rate, sentry
  source maps. Any project-scaffolding skill should reach for this — every new
  project install gets Sentry.
---

# Sentry

Every project install gets Sentry. An app with no error reporting is an app whose failures you hear about from users.

An install is done when all three of these hold:

1. **The DSN is configured** and read from the environment, not hard-coded.
2. **Every sample-rate knob reads one-in-ten** — see [one-in-ten](#one-in-ten).
3. **A deliberate error has landed** in the Sentry project. Until you have seen the event in the UI, the install is unverified.

## one-in-ten

Volume knobs are `0.1`. Error knobs are `1.0`. You want every crash, and a tenth of the traffic.

| Knob | Value | Meaning |
| --- | --- | --- |
| `traces_sample_rate` / `tracesSampleRate` | `0.1` | one request in ten is traced |
| `profiles_sample_rate` / `profileSessionSampleRate` | `0.1` | one traced request in ten is profiled |
| `replaysSessionSampleRate` | `0.1` | one browser session in ten is recorded |
| `sample_rate` (errors) | `1.0` | every error, always |
| `replaysOnErrorSampleRate` | `1.0` | every session that broke |

Read the rate from an env var wherever the SDK allows one, so an incident can be sampled harder without a code change.

**Profiling compounds.** `profiles_sample_rate` is relative to `traces_sample_rate`: one-in-ten of one-in-ten is 1% of requests profiled. That is the intended volume — keep both at `0.1` rather than inflating one to offset the other.

## Where the DSN lives

A DSN names the project and accepts events. It is not a credential, but it stays out of tracked files so environments differ without a deploy.

| Stack | Local | Deployed |
| --- | --- | --- |
| Laravel | `.env` | platform env vars |
| Workers | `.dev.vars` | `wrangler secret put SENTRY_DSN` |
| Browser | `.env.local` (`VITE_SENTRY_DSN`) | build-time env var |

A browser DSN ships inside the bundle and is public by design — that is expected, and rate limiting plus [inbound filters](https://docs.sentry.io/product/data-management-settings/filtering/) are what protect the quota. The value that must never reach a bundle or a tracked file is `SENTRY_AUTH_TOKEN`, which uploads source maps and *is* a credential.

Add the DSN key to `.env.example` (or the equivalent) with an empty value, so the next person knows it exists.

## Pick the stack

| Stack | Guide |
| --- | --- |
| Laravel / PHP | [`references/laravel.md`](references/laravel.md) |
| Hono or plain Cloudflare Workers | [`references/hono-workers.md`](references/hono-workers.md) |
| Browser frontend (React + Vite) | [`references/browser.md`](references/browser.md) |

A full-stack app is **two installs and two Sentry projects** — one per platform, since Sentry projects are platform-typed. A Laravel app with a Vite frontend runs the Laravel guide *and* the browser guide. Set `tracePropagationTargets` on the frontend to your own API origin so the two projects stitch into one distributed trace.

## Releases

Tie every event to a commit so a regression points at a diff.

- Set `SENTRY_RELEASE` to the git SHA in CI: `SENTRY_RELEASE=${{ github.sha }}`.
- Upload source maps from CI for any minified stack (browser bundles, Workers) using `SENTRY_AUTH_TOKEN` as a repo secret. Without maps, a stack trace is one line of mangled output.
- Set `environment` per deploy target (`local`, `staging`, `production`) so staging noise stays out of production alerts.
