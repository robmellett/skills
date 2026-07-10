---
name: laravel-api
description: Build production-grade Laravel REST APIs using a pragmatic Domain-Driven Design architecture. Use when building, scaffolding, or reviewing Laravel APIs organised around a src/Domain layer with business-first naming, invokable versioned controllers, Form Request DTOs (Payloads), invokable Action classes, backed-enum state machines, cross-domain boundaries, JWT authentication, and PSR-12/strict-types code quality. Triggers on "build a Laravel API", "create Laravel endpoints", "add API authentication", "review Laravel API code", "refactor Laravel API", "Laravel domain-driven design", or "improve Laravel code quality".
---

# Laravel API — Pragmatic Domain-Driven Design

Build Laravel REST APIs where the folder tree reads like the product owner's vocabulary. A new engineer should be able to find any business operation in under 10 seconds.

This architecture is inspired by Spatie's _Laravel Beyond CRUD_ but deliberately simplified: **no `laravel-data`, no `laravel-model-states`, no view models**. Pragmatism over purity — calibrated for real-world projects.

## Quick Start

When a user requests a Laravel API, follow this workflow:

1. **Name the domain in business terms** - What capability is this? Use the product owner's word (`Customer`, not `User`; `Broadcast`, not `Job`).
2. **Set up the domain layer** - Add the `Domain\` PSR-4 autoload namespace, scaffold `src/Domain/<Domain>/`.
3. **Build the first operation end-to-end** - Route → Form Request → Payload → Action → Controller → Response to establish the pattern.
4. **Add authentication** - JWT via PHP Open Source Saver.
5. **Iterate on remaining operations** - Follow the established pattern; one Action per user story.

## Core Philosophy

1. **Business-first** - The folder tree mirrors the domain language, not framework defaults.
2. **Stateless by design** - No hidden dependencies; explicit data flow through Payloads.
3. **Boundary-first** - HTTP, business logic, and data layers are cleanly separated.
4. **One operation, one class** - Invokable controllers, invokable Actions, one user story each.
5. **Version discipline** - Namespace-based versioning (`V1`, `V2`), HTTP Sunset headers for deprecation.

## Directory Structure

The **domain (business) layer** lives in `src/Domain/` under the `Domain\` namespace. The **HTTP layer** stays in `app/Http/` under the `App\` namespace. HTTP may depend on Domain; Domain never depends on HTTP.

### Domain layer - `src/Domain/<DomainName>/`

```
src/Domain/<DomainName>/
├── Actions/             ← business operations (invokable)
├── Payloads/            ← typed DTOs (consumed by HTTP, Jobs, CLI)
├── Models/              ← Eloquent — data access only
├── Enums/               ← status, type, role values
├── Events/              ← domain events (optional)
└── Exceptions/          ← domain exceptions (optional)
```

### HTTP layer - `app/Http/`

```
app/Http/
├── Controllers/<Domain>/V1/  ← invokable, versioned
├── Requests/<Domain>/V1/     ← validation + payload()
├── Responses/                ← shared Responsable classes
└── Middleware/
    └── HttpSunset.php

routes/api/
├── routes.php                ← main entry point, version grouping
└── <domain>.php              ← all routes for a domain, all versions
```

### Composer autoload

Register the `Domain\` namespace in `composer.json`, then dump the autoloader:

```json
"autoload": {
    "psr-4": {
        "App\\": "app/",
        "Domain\\": "src/Domain/"
    }
}
```

```bash
composer dump-autoload
```

### Example layout for a `Task` domain

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

Resulting namespaces:
- `Domain\Task\Actions\CreateTaskAction`
- `Domain\Task\Payloads\StoreTaskPayload`
- `App\Http\Controllers\Task\V1\StoreTaskController`

## Architectural Rules

### Rule 1 - Business-first naming

Replace technical defaults with the product owner's vocabulary:

| Framework default | Business name |
|---|---|
| `User` | `Customer` |
| `Job` | `Broadcast` |
| `Task` | `AutomationStep` |

Domains are **singular** (`Task`, not `Tasks`).

### Rule 2 - Invokable controllers, one operation per class

One controller per operation, one `__invoke()` method. Versioned under `V1/`, `V2/` so breaking changes ship safely.

> **Controllers have one job — wire the request to the action and shape the response. No business logic, no model writes.**

The Action is **method-injected** into `__invoke()` and called directly:

```php
final class StoreTaskController
{
    public function __invoke(StoreTaskRequest $request, CreateTaskAction $action): JsonDataResponse
    {
        $task = $action($request->payload());

        return new JsonDataResponse($task, status: 201);
    }
}
```

### Rule 3 - Form Requests carry the payload

Validation **and** DTO construction happen in the `FormRequest`. The `payload()` method returns a typed Payload:

```php
final class StoreTaskRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'title'    => ['required', 'string', 'max:200'],
            'due_at'   => ['nullable', 'date'],
            'priority' => ['required', new Enum(Priority::class)],
        ];
    }

    public function payload(): StoreTaskPayload
    {
        return new StoreTaskPayload(
            title: $this->validated('title'),
            dueAt: $this->date('due_at')?->toImmutable(),
            priority: Priority::from($this->validated('priority')),
        );
    }
}
```

### Rule 4 - Payloads are the boundary DTOs

Plain `final readonly class` with promoted public properties — no external DTO libraries. Payloads live in the **domain** so HTTP, Jobs, and CLI can all consume them.

```php
final readonly class StoreTaskPayload
{
    public function __construct(
        public string $title,
        public ?CarbonImmutable $dueAt,
        public Priority $priority,
    ) {}

    public function toArray(): array
    {
        return [
            'title'    => $this->title,
            'due_at'   => $this->dueAt,
            'priority' => $this->priority->value,
        ];
    }
}
```

> **All communication between layers happens through Payloads. Never pass `array $data` across a boundary.**

### Rule 5 - Actions are business operations

One operation per class, invokable, composed via constructor injection. Wrap multi-write operations in `DB::transaction()`.

```php
final readonly class CreateTaskAction
{
    public function __construct(
        private RecordTaskCreatedAction $recordAuditTrail,
    ) {}

    public function __invoke(StoreTaskPayload $payload): Task
    {
        return DB::transaction(function () use ($payload) {
            $task = Task::create($payload->toArray());

            ($this->recordAuditTrail)($task);

            return $task;
        });
    }
}
```

Conventions:
- Naming: `{Verb}{Domain}Action` (e.g. `CreateTaskAction`).
- Single `__invoke()` - use `handle()` only for queue-job parity.
- Compose other Actions via constructor injection - never `app()` or `resolve()` in the body.
- Guard preconditions early; throw domain exceptions.

> **One action = one user story. If the name doesn't describe a thing a stakeholder might ask for, it's the wrong shape.**

A `Service` class is a rare escape hatch — reach for it only when orchestrating many Actions is genuinely too much for Action-to-Action composition. Prefer composing Actions.

### Rule 6 - Models are data access only

Relationships, casts, and accessors only — no business logic. Use ULIDs over auto-increment IDs for sortability and URL safety.

```php
final class Task extends Model
{
    use HasFactory;
    use HasUlids;

    protected $casts = [
        'priority' => Priority::class,
        'status'   => TaskStatus::class,
        'due_at'   => 'immutable_datetime',
    ];

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
```

### Rule 7 - Responses via `Responsable`

Consistent JSON envelopes through `Responsable` classes. Base success shape is `{ "data": ... }` with optional `{ "meta": ... }`:

```php
final readonly class JsonDataResponse implements Responsable
{
    public function __construct(
        private mixed $data,
        private ?array $meta = null,
        private int $status = 200,
    ) {}

    public function toResponse($request): JsonResponse
    {
        $response = ['data' => $this->data];

        if ($this->meta !== null) {
            $response['meta'] = $this->meta;
        }

        return new JsonResponse($response, $this->status);
    }
}
```

Pair with `JsonErrorResponse` for a consistent error envelope (see Response Format below).

### Rule 8 - State management via enums + guards

Use backed enums with transition logic instead of a state-machine package:

```php
enum TaskStatus: string
{
    case Draft     = 'draft';
    case Active    = 'active';
    case Completed = 'completed';

    public function canTransitionTo(self $next): bool
    {
        return match ($this) {
            self::Draft     => $next === self::Active,
            self::Active    => $next === self::Completed,
            self::Completed => false,
        };
    }
}
```

Guard the transition inside the Action:

```php
final readonly class CompleteTaskAction
{
    public function __invoke(Task $task): Task
    {
        throw_unless(
            $task->status->canTransitionTo(TaskStatus::Completed),
            new InvalidStateTransition(
                "Task {$task->id} cannot be completed from {$task->status->value}",
            ),
        );

        $task->update(['status' => TaskStatus::Completed]);

        return $task;
    }
}
```

Only adopt `spatie/laravel-model-states` if transitions grow complex with side effects or parallel states.

### Rule 9 - Lightweight CQRS at the controller level

Split reads from writes at the **controller** layer, not the query builder:
- **Read** controllers - `IndexTaskController`, `ShowTaskController` → query models directly (Spatie Query Builder is ideal here).
- **Write** controllers - `StoreTaskController`, `UpdateTaskController`, `DestroyTaskController` → always go through an Action.

> **A controller either reads or writes. Never both.**

## PHP Style Requirements

These are mandatory, not optional:

- `declare(strict_types=1);` at the top of **every** file.
- `final readonly class` by default (drop `readonly` only when mutation is necessary — e.g. Eloquent models, which are `final class`).
- Constructor property promotion always.
- Return types and parameter types on **every** method.
- PSR-12 formatting.
- `match` instead of nested ternaries or `if`/`elseif` chains.
- **Never** call `app()`, `resolve()`, `Container::make()`, or facade roots to fetch dependencies inside classes — always use dependency injection. (`DB::transaction()` as a transaction boundary is fine.)
- Models use ULIDs.

## Cross-Domain Boundaries

- Cross-domain calls go through **Actions**, not raw model relationships.
- A domain exposes a few public Actions; everything else stays private.
- Domain Actions may call other domains' Actions, but must **never** `use Domain\Other\Models\...` directly.
- Avoid foreign keys across important boundaries (e.g. billing → CRM) — bridge with IDs and explicit lookups.

## Naming Reference

| Type | Pattern | Example |
|------|---------|---------|
| Action | `{Verb}{Domain}Action` | `CreateTaskAction` |
| Controller | `{Verb}{Domain}Controller` | `StoreTaskController` |
| Request | `{Verb}{Domain}Request` | `StoreTaskRequest` |
| Payload | `{Verb}{Domain}Payload` | `StoreTaskPayload` |
| Response | `{Shape}Response` | `JsonDataResponse`, `JsonErrorResponse` |
| Enum | `{Concept}{Suffix}` | `TaskStatus`, `Priority` |
| Exception | `{Problem}Exception` | `InvalidStateTransition` |

## Building a New Domain Operation

### Step 1 - Routes

Create a domain route file at `routes/api/<domain>.php`:

```php
use App\Http\Controllers\Task\V1;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:api'])->group(function () {
    // Reads — direct model queries
    Route::get('/tasks', V1\IndexTaskController::class);
    Route::get('/tasks/{task}', V1\ShowTaskController::class);

    // Writes — through Actions
    Route::post('/tasks', V1\StoreTaskController::class);
    Route::patch('/tasks/{task}', V1\UpdateTaskController::class);
    Route::delete('/tasks/{task}', V1\DestroyTaskController::class);
});
```

Include it from `routes/api/routes.php`:

```php
Route::prefix('v1')->group(function () {
    require __DIR__ . '/tasks.php';
});
```

### Step 2 - Model (`src/Domain/<Domain>/Models/`)

ULIDs, enum casts, relationships. Data access only. See Rule 6.

### Step 3 - Enums (`src/Domain/<Domain>/Enums/`)

Backed enums for status/type/role, with `canTransitionTo()` guards where state matters. See Rule 8.

### Step 4 - Payload (`src/Domain/<Domain>/Payloads/`)

`final readonly` DTO with promoted properties and `toArray()`. See Rule 4.

### Step 5 - Form Request (`app/Http/Requests/<Domain>/V1/`)

Validation rules + `payload()` returning the DTO. See Rule 3.

### Step 6 - Action (`src/Domain/<Domain>/Actions/`)

Invokable, `{Verb}{Domain}Action`, `DB::transaction()` for multi-write. See Rule 5.

### Step 7 - Controller (`app/Http/Controllers/<Domain>/V1/`)

Invokable, method-injects the Action, returns a `Responsable`. See Rule 2.

## Response Format

**Success:**
```json
{
    "data": {},
    "meta": {}
}
```

**Error (Problem+JSON, RFC 7807):**
```json
{
    "type": "about:blank",
    "title": "Validation Failed",
    "status": 422,
    "detail": "The given data was invalid",
    "errors": {}
}
```

Convert exceptions to Problem+JSON in the application exception handler (see `references/code-examples.md`).

## Query Building (read controllers)

Use Spatie Query Builder on the read side for filtering, sorting, and includes:

```php
use Spatie\QueryBuilder\QueryBuilder;

$tasks = QueryBuilder::for(Task::class)
    ->allowedFilters(['status', 'priority'])
    ->allowedSorts(['created_at', 'due_at'])
    ->allowedIncludes(['project', 'owner'])
    ->paginate();
```

## Versioning Endpoints

When creating V2:

1. Create the V2 namespace: `App\Http\Controllers\Task\V2\`.
2. Add a V2 route group in the domain route file.
3. Add the Sunset middleware to V1 routes:

```php
Route::middleware(['auth:api', 'http.sunset:2025-12-31'])->group(function () {
    // V1 routes
});
```

## Authentication Setup

Use the PHP Open Source Saver JWT package:

```bash
composer require php-open-source-saver/jwt-auth
php artisan vendor:publish --provider="PHPOpenSourceSaver\JWTAuth\Providers\LaravelServiceProvider"
php artisan jwt:secret
```

Configure the guard in `config/auth.php`:

```php
'guards' => [
    'api' => [
        'driver' => 'jwt',
        'provider' => 'users',
    ],
],
```

## Essential Setup

Enable strict mode in `app/Providers/AppServiceProvider.php` to catch N+1 queries early:

```php
use Illuminate\Database\Eloquent\Model;

public function boot(): void
{
    Model::shouldBeStrict();
}
```

Register the HttpSunset middleware alias:

```php
protected $middlewareAliases = [
    'http.sunset' => \App\Http\Middleware\HttpSunset::class,
];
```

## Anti-Patterns to Avoid

- Auto-increment IDs instead of ULIDs.
- Business logic in models.
- Business logic in controllers, or a controller that both reads and writes.
- Multiple operations per controller.
- Passing `array $data` across a boundary instead of a Payload.
- Accessing request data directly in Actions.
- `use Domain\Other\Models\...` - cross-domain access must go through Actions.
- Foreign keys across important domain boundaries.
- Fetching dependencies via `app()` / `resolve()` / facade roots instead of DI.
- String statuses via `Rule::in([...])` instead of backed enums with guards.
- Service classes when Action-to-Action composition would do.
- Breaking changes without versioning; inconsistent response formats.
- Nested ternaries (use `match`); missing type declarations.

## Pre-Ship Checklist

- [ ] Every business operation lives in an Action.
- [ ] Controllers wire only Request → Action → Response.
- [ ] No `array $data` crossing boundaries — Payloads everywhere.
- [ ] Form Requests carry validation **and** the `payload()` method.
- [ ] Models contain no business logic.
- [ ] `declare(strict_types=1)` on every file.
- [ ] Every class is `final` (and `readonly` where applicable).
- [ ] No `app()` / `resolve()` / facade-root dependency fetching — DI everywhere.
- [ ] State transitions gated by enum guards or explicit Actions.
- [ ] Cross-domain access goes through Actions, never foreign models.
- [ ] Tests target Actions and HTTP endpoints, not models.

## Code Review & Refactoring

When reviewing or refactoring, apply these in order:

1. **Preserve functionality** - refactorings change HOW, never WHAT.
2. **Check type safety** - return types, parameter types, `declare(strict_types=1)`.
3. **Simplify logic** - replace nested ternaries with `match`.
4. **Extract complexity** - move complex conditions into named methods.
5. **Verify boundaries** - Payloads across layers, Actions for cross-domain, no facade-root DI.
6. **Improve naming** - business-first, matching the naming table.

### Match over nested ternaries

```php
// ❌ Avoid: nested ternary
$status = $task->completed_at
    ? ($task->verified ? 'verified' : 'completed')
    : ($task->started_at ? 'in_progress' : 'pending');

// ✅ Prefer: match expression
$status = match (true) {
    $task->completed_at && $task->verified => 'verified',
    $task->completed_at => 'completed',
    $task->started_at => 'in_progress',
    default => 'pending',
};
```

## References

- **architecture.md** - comprehensive architectural patterns, the domain/HTTP split, and boundary rules.
- **code-examples.md** - complete working examples for every component.
- **code-quality.md** - Laravel best practices, refactoring patterns, and PSR-12 standards.

## Templates

Template files in `assets/templates/` for quick scaffolding:
- Controller.php
- FormRequest.php
- Payload.php
- Action.php
- Model.php
