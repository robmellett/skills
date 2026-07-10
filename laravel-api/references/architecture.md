# Pragmatic Laravel DDD Architecture

Inspired by Spatie's _Laravel Beyond CRUD_ but deliberately simplified: no `laravel-data`, no `laravel-model-states`, no view models. The goal is that the folder tree reads like the product owner's vocabulary, and a new engineer can find any business operation in under 10 seconds.

## Core Principles

### 1. Business-first naming
- The folder tree mirrors the domain language, not framework defaults (`Customer` not `User`, `Broadcast` not `Job`).
- Domains are singular (`Task`, not `Tasks`).

### 2. Stateless by design
- No hidden dependencies in models or actions.
- Explicit data flow through Payloads (DTOs).
- Query building over implicit scopes.
- Strict mode enabled to catch N+1 issues early.

### 3. Boundary-first
- Clear separation between HTTP, business logic, and data layers.
- Form Requests handle validation and construct Payloads.
- DTOs carry data between layers
- Actions contain business logic.
- Models are data access only.
- HTTP may depend on Domain; Domain never depends on HTTP.

### 4. One operation, one class
- Invokable controllers (one `__invoke()`), invokable Actions (one user story).

### 5. Version discipline
- Versioning through namespacing (`V1`, `V2`).
- HTTP Sunset headers for deprecation warnings.
- Keep old versions working; don't break existing clients.

### 6. Code quality standards
- `declare(strict_types=1)` on every file.
- `final readonly class` by default; return/parameter types everywhere.
- `match` over nested ternaries; PSR-12 formatting.
- No `app()` / `resolve()` / facade-root dependency fetching — dependency injection everywhere.

## Two-Layer Structure

The **domain (business) layer** lives in `src/Domain/` under the `Domain\` namespace. The **HTTP layer** stays in `app/Http/` under the `App\` namespace.

### Domain layer — `src/Domain/<DomainName>/`

```
src/Domain/<DomainName>/
├── Actions/             # business operations (invokable)
├── Payloads/            # typed DTOs (consumed by HTTP, Jobs, CLI)
├── Models/              # Eloquent — data access only
├── Enums/               # status, type, role values
├── Events/              # domain events (optional)
└── Exceptions/          # domain exceptions (optional)
```

### HTTP layer — `app/Http/`

```
app/Http/
├── Controllers/<Domain>/V1/   # invokable, versioned
├── Requests/<Domain>/V1/      # validation + payload()
├── Responses/                 # shared Responsable classes
│   ├── JsonDataResponse.php
│   └── JsonErrorResponse.php
└── Middleware/
    └── HttpSunset.php

routes/api/
├── routes.php                 # main API routing file, version grouping
└── <domain>.php               # all routes for a domain, all versions
```

### Composer autoload

```json
"autoload": {
    "psr-4": {
        "App\\": "app/",
        "Domain\\": "src/Domain/"
    }
}
```

Run `composer dump-autoload` after adding the namespace.

### Worked example — `Task` domain

```
src/Domain/Task/
├── Actions/
│   ├── CreateTaskAction.php
│   ├── CompleteTaskAction.php
│   └── RecordTaskCreatedAction.php
├── Payloads/
│   └── StoreTaskPayload.php
├── Models/
│   └── Task.php
├── Enums/
│   ├── TaskStatus.php
│   └── Priority.php
└── Exceptions/
    └── InvalidStateTransition.php

app/Http/
├── Controllers/Task/V1/
│   ├── IndexTaskController.php
│   ├── ShowTaskController.php
│   └── StoreTaskController.php
├── Requests/Task/V1/
│   └── StoreTaskRequest.php
└── Responses/
    ├── JsonDataResponse.php
    └── JsonErrorResponse.php
```

Namespaces:
- `Domain\Task\Actions\CreateTaskAction`
- `Domain\Task\Payloads\StoreTaskPayload`
- `App\Http\Controllers\Task\V1\StoreTaskController`

## Component Patterns

### Models
- Live in `Domain\<Domain>\Models`.
- Always use ULIDs instead of auto-incrementing IDs.
- Cast statuses/types to backed enums and dates to `immutable_datetime`.
- `Model::shouldBeStrict()` in `AppServiceProvider` to prevent N+1 issues.
- Data access only — no business logic.

### Enums
- Live in `Domain\<Domain>\Enums`.
- Backed enums model status/type/role values.
- Encode allowed transitions with a `canTransitionTo(self $next): bool` method using `match`.

### Payloads (DTOs)
- Live in `Domain\<Domain>\Payloads` (domain-level so HTTP, Jobs, and CLI can all consume them).
- `final readonly class` with promoted public properties.
- `toArray()` for persistence; no business logic.
- **All communication between layers happens through Payloads. Never pass `array $data` across a boundary.**

### Form Requests
- Live in `App\Http\Requests\<Domain>\V1`.
- Handle validation rules.
- Expose a `payload()` method that builds the domain Payload from `validated()` data.
- Validate enums with `new Enum(SomeEnum::class)`.

### Actions
- Live in `Domain\<Domain>\Actions`.
- Named `{Verb}{Domain}Action`; single `__invoke()` (or `handle()` for queue-job parity).
- Compose other Actions via constructor injection — never `app()`/`resolve()` in the body.
- Wrap multi-write operations in `DB::transaction()`.
- Guard preconditions early; throw domain exceptions.
- **One action = one user story.** If the name doesn't describe something a stakeholder might ask for, it's the wrong shape.

### Services (rare escape hatch)
- Only when orchestrating many Actions is genuinely too much for Action-to-Action composition.
- Prefer composing Actions over introducing a Service.

### Controllers
- Live in `App\Http\Controllers\<Domain>\V1`.
- Invokable, one operation per class, named `{Verb}{Domain}Controller`.
- **Controllers have one job: wire the request to the action and shape the response. No business logic, no model writes.**
- Method-inject the Action into `__invoke()` and call it directly.

### Response classes
- Implement `Responsable`; live in `App\Http\Responses`.
- Base success envelope: `{ "data": ... }`, with optional `{ "meta": ... }`.
- Errors use `application/problem+json` (RFC 7807) via `JsonErrorResponse` / the exception handler.

### Routing
- Main entry: `routes/api/routes.php`.
- Domain files: `routes/api/<domain>.php`.
- Group by version; apply version-specific middleware (including HTTP Sunset).

### Query building (read side)
- Use Spatie Query Builder in read controllers.
- Explicit eager loading with `allowedIncludes()`; avoid hidden scopes.

## Lightweight CQRS (controller level)

Split reads from writes at the controller layer, not the query builder:
- **Read** controllers (`Index`, `Show`) query models directly.
- **Write** controllers (`Store`, `Update`, `Destroy`) always go through an Action.

**A controller either reads or writes. Never both.**

## State Management (enums + guards)

Model state with backed enums that own their transition rules, and guard the transition inside the Action with `throw_unless(...)`. Only adopt `spatie/laravel-model-states` if transitions grow complex with side effects or parallel states.

## Cross-Domain Boundaries

- Cross-domain calls go through **Actions**, not raw model relationships.
- A domain exposes a few public Actions; everything else stays private.
- Domain Actions may call other domains' Actions, but never `use Domain\Other\Models\...` directly.
- Avoid foreign keys across important boundaries (e.g. billing → CRM) — bridge with IDs and explicit lookups.

## Authentication
- JWT tokens via the PHP Open Source Saver package.
- Stateless authentication; token in `Authorization: Bearer {token}`.
- Refresh token flow for long-lived sessions.

## Common Workflows

### Creating a new operation

1. Add route in `routes/api/<domain>.php`.
2. Create/extend the model in `Domain\<Domain>\Models`.
3. Add backed enums in `Domain\<Domain>\Enums` (with transition guards).
4. Create the Payload in `Domain\<Domain>\Payloads`.
5. Create the Form Request in `App\Http\Requests\<Domain>\V1` with a `payload()` method.
6. Create the Action in `Domain\<Domain>\Actions`.
7. Create the invokable Controller in `App\Http\Controllers\<Domain>\V1`.

### Versioning an operation

1. Create the V2 namespace: `App\Http\Controllers\<Domain>\V2`.
2. Copy and modify the controller from V1; update Request/Payload if the contract changes.
3. Add a V2 route group in `routes/api/<domain>.php`.
4. Add the Sunset header/middleware to V1 routes.

### Adding query capabilities (read controller)

```php
use Spatie\QueryBuilder\QueryBuilder;

$tasks = QueryBuilder::for(Task::class)
    ->allowedFilters(['status', 'priority'])
    ->allowedSorts(['created_at', 'due_at'])
    ->allowedIncludes(['project', 'owner'])
    ->paginate();
```

## Anti-Patterns to Avoid

- ❌ Auto-incrementing IDs (use ULIDs)
- ❌ Business logic in models
- ❌ Business logic in controllers, or a controller that both reads and writes
- ❌ Multiple operations per controller
- ❌ Passing `array $data` across a boundary instead of a Payload
- ❌ Direct request access in Actions
- ❌ `use Domain\Other\Models\...` — cross-domain access must go through Actions
- ❌ Foreign keys across important domain boundaries
- ❌ Fetching dependencies via `app()` / `resolve()` / facade roots
- ❌ String statuses via `Rule::in([...])` instead of backed enums with guards
- ❌ Service classes when Action-to-Action composition would do
- ❌ Breaking changes without versioning
- ❌ Inconsistent response formats
- ❌ Nested ternary operators; missing type declarations

## Pre-Ship Checklist

- Every business operation lives in an Action.
- Controllers wire only Request → Action → Response.
- No `array $data` crossing boundaries — Payloads everywhere.
- Form Requests carry validation **and** the `payload()` method.
- Models contain no business logic.
- `declare(strict_types=1)` on every file.
- Every class is `final` (and `readonly` where applicable).
- No `app()` / `resolve()` / facade-root dependency fetching.
- State transitions gated by enum guards or explicit Actions.
- Cross-domain access goes through Actions, never foreign models.
- Tests target Actions and HTTP endpoints, not models.
