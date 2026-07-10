---
name: new-laravel
description: Preferred tech stack defaults
---

# New Project

## Tech Stack

This project uses the following mandatory stack. Do not suggest alternatives.

### Backend
- **PHP framework**: Laravel 13+
- **Database**: PostgreSQL (via Laravel Sail)
- Do not use plain PHP, Lumen, Symfony, or any other framework

### Frontend
- **Bundler**: Vite+ (latest stable Vite, `vite.config.ts`)
- **Styling**: Tailwind CSS 4+
- **Language**: TypeScript 7+


### Package Manager
- **Always use pnpm** — never npm or yarn
- All install instructions must use `pnpm add`, `pnpm install`, `pnpm dlx`
- Lock file: `pnpm-lock.yaml`

---

## Code Conventions

### TypeScript
- Target: ESNext
- Strict mode: enabled (`"strict": true` in tsconfig)
- Use `.ts` / `.tsx` extensions throughout
- Prefer `type` over `interface` unless extending

### Tailwind CSS
- Use Tailwind 4+ syntax (CSS-first config via `@import "tailwindcss"`)
- Do not use `tailwind.config.js` — Tailwind 4 is configured in CSS
- Utility-first: avoid writing custom CSS unless absolutely necessary

### Vite
- Config file: `vite.config.ts`
- Use Vite plugins for all integrations
- Dev server port: 5173 (default)

### Laravel
- Use Laravel 13+ conventions
- Prefer Eloquent over raw queries
- API routes in `routes/api.php`, must be prefixed with `/v1/`
- Frontend served via Vite integration (`@vite` directive or separate SPA)
- Format with Laravel Pint using the bundled `pint.json` — `declare(strict_types=1)` is enforced in every PHP file
- Static-analyse with Larastan, configured via `phpstan.neon`
- Install and configure the required packages — see [Laravel setup](#laravel-setup)

---

## Laravel setup

Run these inside the freshly-created Laravel app, in order.

### Required packages

```bash
composer require nunomaduro/essentials
composer require spatie/laravel-data
composer require spatie/laravel-ray --dev
composer require --dev "larastan/larastan"
composer require laravel/sail --dev
```

- **`nunomaduro/essentials`** — opinionated defaults (strict models, immutable dates, force HTTPS, safe console). Applies automatically after install.
- **`spatie/laravel-data`** — typed DTOs.
- **`spatie/laravel-ray`** — dev-only debugging; works out of the box.
- **`larastan/larastan`** — PHPStan for Laravel (configured via `phpstan.neon` below).
- **`laravel/sail`** — Docker dev environment.

### Configure

```bash
# essentials is on by default — publish the config only to toggle features (config/essentials.php)
php artisan vendor:publish --tag=essentials-config

# Sail + PostgreSQL, with a VS Code devcontainer
php artisan sail:install --with="pgsql" --devcontainer
```

### `pint.json`

Place in the project root:

```json
{
    "preset": "laravel",
    "rules": {
        "declare_strict_types": true,
        "single_line_empty_body": false,
        "multiline_promoted_properties": true
    }
}
```

### `phpstan.neon`

Place in the project root. Start at level 5 and raise it as the codebase allows:

```neon
includes:
    - vendor/larastan/larastan/extension.neon

parameters:
    paths:
        - app/
        - src/
        
    level: 7
```

---

## Commands

Frontend (always pnpm — never npm or yarn):

```bash
# Install dependencies
pnpm install

# Dev server
pnpm dev

# Build
pnpm build

# Type check
pnpm tsc --noEmit
```

Laravel / PHP:

```bash
./vendor/bin/pint             # format (uses pint.json)
./vendor/bin/phpstan analyse  # static analysis (Larastan)
./vendor/bin/sail up -d       # start the Sail dev environment
```

---

## Do Not
- Use npm or yarn
- Use webpack
- Use Tailwind 3 or below syntax
- Use plain PHP or non-Laravel frameworks
- Use JavaScript (.js) where TypeScript (.ts/.tsx) is possible
- Use Node.js runtime where Cloudflare Workers is applicable
