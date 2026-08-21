# Sentry — Laravel

`sentry/sentry-laravel` (latest `4.x`, supports Laravel 11–13 on PHP 8.2+).

## 1. Install

```bash
composer require sentry/sentry-laravel
php artisan sentry:publish --dsn=<paste-dsn>
```

`sentry:publish` writes `config/sentry.php` and appends the DSN to `.env`.

## 2. Wire exceptions

Laravel 11+ reports through `bootstrap/app.php` — without this call, nothing is captured:

```php
use Sentry\Laravel\Integration;

->withExceptions(function (Exceptions $exceptions): void {
    Integration::handles($exceptions);
})
```

## 3. Sample rates

`.env` (and the same keys in `.env.example`, values blank):

```dotenv
SENTRY_LARAVEL_DSN=
SENTRY_ENVIRONMENT=local
SENTRY_TRACES_SAMPLE_RATE=0.1
SENTRY_PROFILES_SAMPLE_RATE=0.1
SENTRY_SEND_DEFAULT_PII=false
```

Both sample rates default to `null` (off) when the env var is absent, so setting them is what turns tracing on. Errors ride `SENTRY_SAMPLE_RATE`, which defaults to `1.0` — leave it alone.

`send_default_pii` stays `false`: it keeps request bodies, cookies, and user identifiers out of events. Turn it on deliberately, per project, not by default.

## 4. Profiling needs excimer

`profiles_sample_rate` is inert without the PHP extension:

```bash
pecl install excimer
```

Under Sail, the base image doesn't carry it. Publish the Docker files and add the extension:

```bash
php artisan sail:publish
```

Then in the published `docker/<php-version>/Dockerfile`, alongside the other extension installs:

```dockerfile
RUN pecl install excimer && docker-php-ext-enable excimer
```

```bash
./vendor/bin/sail build --no-cache
```

## 5. Route logs into Sentry

`Log::error()` reaching Sentry takes a log channel. In `config/logging.php`:

```php
'sentry' => [
    'driver' => 'sentry',
    'level' => env('LOG_LEVEL', 'error'),
    'bubble' => true,
],
```

Then add `sentry` to the `stack` channel's `channels` array so it runs beside the file log rather than replacing it.

## 6. Verify

```bash
php artisan sentry:test
```

This sends a test event and a test transaction, and reports what the SDK actually resolved — DSN, environment, sample rates. A pass here plus the event visible in Sentry is the install's completion criterion.

Queued jobs, scheduled commands, and Octane requests are instrumented by the package once the DSN is set — no extra wiring.

## 7. Release from CI

```dotenv
SENTRY_RELEASE=<git-sha>
```

Set it as a deploy-time env var. Frontend assets built by Vite need the browser guide as well — the PHP install does not cover them.
