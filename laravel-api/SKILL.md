---
name: laravel-api
description: Build production-grade Laravel REST APIs using a pragmatic Domain-Driven Design architecture. Use when building, scaffolding, or reviewing Laravel APIs organised around a src/Domain layer with business-first naming, invokable versioned controllers, Form Request DTOs, invokable Action classes, backed-enum state machines, cross-domain boundaries, Sanctum authentication, and PSR-12/strict-types code quality. Triggers on "build a Laravel API", "create Laravel endpoints", "add API authentication", "review Laravel API code", "refactor Laravel API", "Laravel domain-driven design", or "improve Laravel code quality".
---

# Laravel API — Pragmatic Domain-Driven Design

Build Laravel REST APIs where the folder tree reads like the product owner's vocabulary. A new engineer should be able to find any business operation in under 10 seconds.

This architecture is inspired by Spatie's _Laravel Beyond CRUD_ but deliberately simplified: **no `laravel-data`, no `laravel-model-states`, no view models**. Pragmatism over purity — calibrated for real-world projects.

## Quick Start

When a user requests a Laravel API, follow this workflow:

1. **Name the domain in business terms** - What capability is this? Use the product owner's word (`Customer`, not `User`; `Broadcast`, not `Job`).
2. **Set up the domain layer** - Add the `Domain\` PSR-4 autoload namespace, scaffold `src/Domain/<Domain>/`.
3. **Build the first operation end-to-end** - Route → Form Request → DTO → Action → Controller → Response to establish the pattern.
4. **Add authentication** - Laravel Sanctum (token-based, `auth:sanctum`).
5. **Iterate on remaining operations** - Follow the established pattern; one Action per user story.

## Core Philosophy

1. **Business-first** - The folder tree mirrors the domain language, not framework defaults.
2. **Stateless by design** - No hidden dependencies; explicit data flow through DTOs.
3. **Boundary-first** - HTTP, business logic, and data layers are cleanly separated.
4. **One operation, one class** - Invokable controllers, single-purpose Actions, one user story each.
5. **Version discipline** - Namespace-based versioning (`V1`, `V2`), HTTP Sunset headers for deprecation.

## Directory Structure

The **domain (business) layer** lives in `src/Domain/` under the `Domain\` namespace. The **HTTP layer** stays in `app/Http/` under the `App\` namespace. HTTP may depend on Domain; Domain never depends on HTTP.

### Domain layer - `src/Domain/<DomainName>/`

```
src/Domain/<DomainName>/
├── Actions/             ← business operations (invokable)
├── DTOs/                ← typed data transfer objects (consumed by HTTP, Jobs, CLI)
├── Models/              ← Eloquent — data access only
├── Enums/               ← status, type, role values
├── Events/              ← domain events (optional)
└── Exceptions/          ← domain exceptions (optional)
```

### HTTP layer - `app/Http/`

```
app/Http/
├── Controllers/<Domain>/V1/  ← invokable, versioned
├── Requests/<Domain>/V1/     ← validation + dto()
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
├── DTOs/
│   └── StoreTaskDTO.php
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
- `Domain\Task\DTOs\StoreTaskDTO`
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

The controller resolves the Action via its static `make()` factory and calls `execute()`:

```php
final class StoreTaskController
{
    public function __invoke(StoreTaskRequest $request): JsonDataResponse
    {
        $task = CreateTaskAction::make()->execute($request->dto());

        return new JsonDataResponse($task, status: 201);
    }
}
```

### Rule 3 - Form Requests carry the DTO

Validation **and** DTO construction happen in the `FormRequest`. The `dto()` method returns a typed DTO:

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

    public function dto(): StoreTaskDTO
    {
        return new StoreTaskDTO(
            title: $this->validated('title'),
            dueAt: $this->date('due_at')?->toImmutable(),
            priority: Priority::from($this->validated('priority')),
        );
    }
}
```

### Rule 4 - DTOs are the boundary objects

Plain `final readonly class` with promoted public properties — no external DTO libraries. DTOs live in the **domain** so HTTP, Jobs, and CLI can all consume them.

```php
final readonly class StoreTaskDTO
{
    public function __construct(
        public string $title,
        public ?CarbonImmutable $dueAt,
        public Priority $priority,
    ) {
    }

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

> **All communication between layers happens through DTOs. Never pass `array $data` across a boundary.**

### Rule 5 - Actions are business operations

One operation per class, composed via constructor injection. Wrap multi-write operations in `DB::transaction()`.

```php
final readonly class CreateTaskAction
{
    public static function make(): static
    {
        return app(static::class);
    }

    public function __construct(
        private RecordTaskCreatedAction $recordAuditTrail,
    ) {
    }

    public function execute(StoreTaskDTO $dto): Task
    {
        return DB::transaction(function () use ($dto) {
            $task = Task::create($dto->toArray());

            $this->recordAuditTrail->execute($task);

            return $task;
        });
    }
}
```

Conventions:
- Naming: `{Verb}{Domain}Action` (e.g. `CreateTaskAction`).
- Expose a static `make()` factory (`return app(static::class);`) and an `execute()` method. Invoke as `SomeAction::make()->execute(...)`.
- Compose other Actions via constructor injection - never `app()` or `resolve()` in the body (the `make()` factory is the one exception).
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
    ) {
    }

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
    public static function make(): static
    {
        return app(static::class);
    }

    public function execute(Task $task): Task
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
- **Never** call `app()`, `resolve()`, `Container::make()`, or facade roots to fetch dependencies inside classes — always use dependency injection. (Exceptions: the Action's static `make()` factory, and `DB::transaction()` as a transaction boundary.)
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
| DTO | `{Verb}{Domain}DTO` | `StoreTaskDTO` |
| Response | `{Shape}Response` | `JsonDataResponse`, `JsonErrorResponse` |
| Enum | `{Concept}{Suffix}` | `TaskStatus`, `Priority` |
| Exception | `{Problem}Exception` | `InvalidStateTransition` |

## Building a New Domain Operation

### Step 1 - Routes

Create a domain route file at `routes/api/<domain>.php`:

```php
use App\Http\Controllers\Task\V1;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum'])->group(function () {
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

### Step 4 - DTO (`src/Domain/<Domain>/DTOs/`)

`final readonly` DTO with promoted properties and `toArray()`. See Rule 4.

### Step 5 - Form Request (`app/Http/Requests/<Domain>/V1/`)

Validation rules + `dto()` returning the DTO. See Rule 3.

### Step 6 - Action (`src/Domain/<Domain>/Actions/`)

Invokable, `{Verb}{Domain}Action`, `DB::transaction()` for multi-write. See Rule 5.

### Step 7 - Controller (`app/Http/Controllers/<Domain>/V1/`)

Invokable; calls `Action::make()->execute()`, returns a `Responsable`. See Rule 2.

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
Route::middleware(['auth:sanctum', 'http.sunset:2025-12-31'])->group(function () {
    // V1 routes
});
```

## Authentication Setup

Use **Laravel Sanctum** for API authentication — never JWT. On Laravel 11+, scaffold the API layer (this installs Sanctum, publishes its migration, and creates `routes/api.php`):

```bash
php artisan install:api
```

Add the `HasApiTokens` trait to the authenticatable model:

```php
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Foundation\Auth\User as Authenticatable;

final class User extends Authenticatable
{
    use HasApiTokens;
}
```

Issue a token (e.g. in a login Action) and return the plain-text value to the client once:

```php
$token = $user->createToken('api')->plainTextToken;
```

Protect routes with the `auth:sanctum` middleware. Clients authenticate by sending `Authorization: Bearer {token}`.

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

### Formatting — Laravel Pint

Format all code with Laravel Pint using the project `pint.json`:

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

- `declare_strict_types` — enforces `declare(strict_types=1)` on every file.
- `single_line_empty_body: false` — keep empty bodies expanded (`) {` then `}`), not collapsed to `) {}`.
- `multiline_promoted_properties` — one promoted constructor property per line.

```bash
composer require laravel/pint --dev
./vendor/bin/pint
```

## Anti-Patterns to Avoid

- Auto-increment IDs instead of ULIDs.
- Business logic in models.
- Business logic in controllers, or a controller that both reads and writes.
- Multiple operations per controller.
- Passing `array $data` across a boundary instead of a DTO.
- Accessing request data directly in Actions.
- `use Domain\Other\Models\...` - cross-domain access must go through Actions.
- Foreign keys across important domain boundaries.
- Fetching dependencies via `app()` / `resolve()` / facade roots outside the Action `make()` factory.
- String statuses via `Rule::in([...])` instead of backed enums with guards.
- Service classes when Action-to-Action composition would do.
- JWT for authentication — use Laravel Sanctum.
- Breaking changes without versioning; inconsistent response formats.
- Nested ternaries (use `match`); missing type declarations.

## Pre-Ship Checklist

- [ ] Every business operation lives in an Action.
- [ ] Controllers wire only Request → Action → Response.
- [ ] No `array $data` crossing boundaries — DTOs everywhere.
- [ ] Form Requests carry validation **and** the `dto()` method.
- [ ] Models contain no business logic.
- [ ] `declare(strict_types=1)` on every file.
- [ ] Every class is `final` (and `readonly` where applicable).
- [ ] No `app()` / `resolve()` / facade-root dependency fetching — DI everywhere.
- [ ] State transitions gated by enum guards or explicit Actions.
- [ ] Cross-domain access goes through Actions, never foreign models.
- [ ] Authentication uses Sanctum (`auth:sanctum`), not JWT.
- [ ] Tests target Actions and HTTP endpoints, not models.

## Code Review & Refactoring

When reviewing or refactoring, apply these in order:

1. **Preserve functionality** - refactorings change HOW, never WHAT.
2. **Check type safety** - return types, parameter types, `declare(strict_types=1)`.
3. **Simplify logic** - replace nested ternaries with `match`.
4. **Extract complexity** - move complex conditions into named methods.
5. **Verify boundaries** - DTOs across layers, Actions for cross-domain, no facade-root DI.
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
- DTO.php
- Action.php
- Model.php
