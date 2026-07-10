---
name: laravel-beyond-crud
description: Structure Laravel projects using Spatie's Beyond CRUD domain-oriented architecture — domains, application layers, Actions, DTOs (spatie/laravel-data), model states, custom query builders, and view models. Use when scaffolding a new Laravel domain, refactoring fat controllers/models into domain code, or when the user mentions Beyond CRUD, DDD-lite, Actions, DTOs, domain layer, or Spatie architecture patterns.
---

# Laravel Beyond CRUD (Spatie Domain Architecture)

Domain-oriented Laravel per Spatie's Beyond CRUD. Business logic lives in **Domains** (grouped by business concept), while HTTP/console/admin concerns live in **Application layers**. Complements `laravel-best-practices` — that skill covers general Laravel rules; this one covers architecture.

## Directory Structure

```
src/
├── Domain/
│   ├── Orders/
│   │   ├── Actions/           # CreateOrderAction, MarkOrderPaidAction
│   │   ├── Collections/       # OrderCollection
│   │   ├── DataTransferObjects/  # OrderData (spatie/laravel-data)
│   │   ├── Enums/             # OrderType (native backed enums)
│   │   ├── Events/
│   │   ├── Exceptions/        # CouldNotCreateOrder::becauseX()
│   │   ├── Models/            # Order (thin)
│   │   ├── QueryBuilders/     # OrderQueryBuilder
│   │   ├── Rules/
│   │   └── States/            # OrderState (spatie/laravel-model-states)
│   └── Payments/
└── App/
    ├── Admin/                 # Filament panel / admin controllers
    ├── Api/
    │   └── Orders/
    │       ├── Controllers/
    │       ├── Requests/      # Validation only — map to DTO
    │       ├── Resources/
    │       └── ViewModels/
    └── Console/
```

Namespace mapping in `composer.json`: `"Domain\\": "src/Domain/"`, `"App\\": "src/App/"` (keep `App` as root namespace so framework defaults work; set `$namespace` handling for smaller projects — a plain `app/Domain` + `app/App` split inside `app/` is also acceptable).

**Rule of thumb**: Domains never depend on Application layers. Application layers orchestrate: Request → DTO → Action → Resource/ViewModel.

## Core Patterns

### Actions
One verb-named class per business operation, single `execute()` (or `__invoke`) method, constructor DI, composable (actions call actions). Return domain objects, never HTTP responses. See [PATTERNS.md](PATTERNS.md#actions).

### DTOs
`spatie/laravel-data` classes, `readonly`, typed properties. Form requests validate then hand off via `OrderData::from($request)`. No arrays crossing layer boundaries. See [PATTERNS.md](PATTERNS.md#dtos).

### Models stay thin
Persistence config, casts, relations only. Move query scopes → custom `QueryBuilder`, collection logic → custom `Collection`, business rules → Actions, lifecycle → States. See [PATTERNS.md](PATTERNS.md#models).

### States
`spatie/laravel-model-states` for lifecycle with behavior (e.g. `PendingOrderState → PaidOrderState`); transitions as classes with side effects. Use plain enums when there's no behavior. See [PATTERNS.md](PATTERNS.md#states).

### Exceptions
Domain exceptions with named constructors: `CouldNotCreateOrder::becauseCustomerIsBlocked($customer)`. Pair with the `laravel-http-sentry-exceptions` skill for third-party API failures.

### View Models / Resources
App-layer classes shaping domain data for a specific view/endpoint. Never pass models straight to complex views.

## Workflow: New Domain Feature

1. Identify/create the domain folder
2. DTO for the input data
3. Action(s) implementing the operation — unit test with Pest first
4. Model changes: casts, relations, query builder methods
5. App layer: Request (validation) → Controller (thin: DTO → Action → Response) → Resource/ViewModel
6. `tests/Domain/...` unit tests, `tests/App/...` feature tests

## Conventions (project defaults)

- `declare(strict_types=1);` in every file
- PHP 8.3+: readonly properties, enums, first-class callables, promoted constructors
- Pest for tests; PHPStan/Larastan level 8+
- Never put business logic in controllers, form requests, or Blade

Full code examples: [PATTERNS.md](PATTERNS.md) · Testing: [TESTING.md](TESTING.md)
