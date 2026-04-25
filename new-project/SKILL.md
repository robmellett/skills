# {{PROJECT_NAME}} — Claude Project Configuration

## Tech Stack

This project uses the following mandatory stack. Do not suggest alternatives.

### Backend
- **PHP framework**: Laravel 13+
- Do not use plain PHP, Lumen, Symfony, or any other framework

### Frontend
- **Bundler**: Vite+ (latest stable Vite, `vite.config.ts`)
- **Framework**: React (via `@vitejs/plugin-react`)
- **Styling**: Tailwind CSS 4+
- **Language**: TypeScript 7+

### Edge / Deployment
- **Runtime**: Cloudflare Workers
- Use `vite-plugin-cloudflare` or `wrangler` for Workers integration

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
- Use Laravel Pint for formatting
- API routes in `routes/api.php`, must be prefixed with `/v1/`
- Frontend served via Vite integration (`@vite` directive or separate SPA)
- Must install `composer require nunomaduro/essentials`
- Must install `composer require spatie/laravel-data`
- Must install `composer require spatie/laravel-ray --dev`
- Must install `composer require --dev "larastan/larastan:^3.0"`
- Must install `composer require laravel/sail --dev`


---

## Commands

All commands use pnpm:

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

---

## Do Not
- Use npm or yarn
- Use webpack
- Use Tailwind 3 or below syntax
- Use plain PHP or non-Laravel frameworks
- Use JavaScript (.js) where TypeScript (.ts/.tsx) is possible
- Use Node.js runtime where Cloudflare Workers is applicable
