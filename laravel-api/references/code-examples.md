# Code Examples

Complete, working examples of each component in the pragmatic Laravel DDD architecture. Domain (business) classes live under `src/Domain/` in the `Domain\` namespace; HTTP classes live under `app/Http/` in the `App\` namespace.

## Enum (`src/Domain/Task/Enums/`)

```php
<?php

declare(strict_types=1);

namespace Domain\Task\Enums;

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

```php
<?php

declare(strict_types=1);

namespace Domain\Task\Enums;

enum Priority: string
{
    case Low    = 'low';
    case Medium = 'medium';
    case High   = 'high';
}
```

## Model with ULID (`src/Domain/Task/Models/`)

Models are `final class` (not `readonly` — Eloquent mutates them). Data access only.

```php
<?php

declare(strict_types=1);

namespace Domain\Task\Models;

use Domain\Task\Enums\Priority;
use Domain\Task\Enums\TaskStatus;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

final class Task extends Model
{
    use HasFactory;
    use HasUlids;

    protected $fillable = [
        'title',
        'description',
        'status',
        'priority',
        'due_at',
        'project_id',
    ];

    protected $casts = [
        'status'   => TaskStatus::class,
        'priority' => Priority::class,
        'due_at'   => 'immutable_datetime',
    ];

    public function project(): BelongsTo
    {
        return $this->belongsTo(Project::class);
    }
}
```

## DTO (`src/Domain/Task/DTOs/`)

```php
<?php

declare(strict_types=1);

namespace Domain\Task\DTOs;

use Carbon\CarbonImmutable;
use Domain\Task\Enums\Priority;

final readonly class StoreTaskDTO
{
    public function __construct(
        public string $title,
        public ?string $description,
        public ?CarbonImmutable $dueAt,
        public Priority $priority,
        public string $projectId,
    ) {
    }

    public function toArray(): array
    {
        return [
            'title'       => $this->title,
            'description' => $this->description,
            'due_at'      => $this->dueAt,
            'priority'    => $this->priority->value,
            'project_id'  => $this->projectId,
        ];
    }
}
```

## Form Request with dto() (`app/Http/Requests/Task/V1/`)

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests\Task\V1;

use Domain\Task\Enums\Priority;
use Domain\Task\DTOs\StoreTaskDTO;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Enum;

final class StoreTaskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title'       => ['required', 'string', 'max:200'],
            'description' => ['nullable', 'string', 'max:1000'],
            'due_at'      => ['nullable', 'date', 'after:now'],
            'priority'    => ['required', new Enum(Priority::class)],
            'project_id'  => ['required', 'string', 'exists:projects,id'],
        ];
    }

    public function dto(): StoreTaskDTO
    {
        return new StoreTaskDTO(
            title: $this->validated('title'),
            description: $this->validated('description'),
            dueAt: $this->date('due_at')?->toImmutable(),
            priority: Priority::from($this->validated('priority')),
            projectId: $this->validated('project_id'),
        );
    }
}
```

## Action — create with composition + transaction (`src/Domain/Task/Actions/`)

```php
<?php

declare(strict_types=1);

namespace Domain\Task\Actions;

use Domain\Task\DTOs\StoreTaskDTO;
use Domain\Task\Models\Task;
use Illuminate\Support\Facades\DB;

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

## Action — state transition with guard

```php
<?php

declare(strict_types=1);

namespace Domain\Task\Actions;

use Domain\Task\Enums\TaskStatus;
use Domain\Task\Exceptions\InvalidStateTransition;
use Domain\Task\Models\Task;

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

## Domain Exception (`src/Domain/Task/Exceptions/`)

```php
<?php

declare(strict_types=1);

namespace Domain\Task\Exceptions;

use RuntimeException;

final class InvalidStateTransition extends RuntimeException
{
}
```

## Write controller (`app/Http/Controllers/Task/V1/`)

The controller resolves the Action via its static `make()` factory and runs it with `execute()` — wiring Request → Action → Response.

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Task\V1;

use App\Http\Requests\Task\V1\StoreTaskRequest;
use App\Http\Responses\JsonDataResponse;
use Domain\Task\Actions\CreateTaskAction;

final class StoreTaskController
{
    public function __invoke(StoreTaskRequest $request): JsonDataResponse
    {
        $task = CreateTaskAction::make()->execute($request->dto());

        return new JsonDataResponse($task, status: 201);
    }
}
```

## Read controller with Query Builder (CQRS read side)

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Task\V1;

use App\Http\Responses\JsonDataResponse;
use Domain\Task\Models\Task;
use Spatie\QueryBuilder\QueryBuilder;

final class IndexTaskController
{
    public function __invoke(): JsonDataResponse
    {
        $tasks = QueryBuilder::for(Task::class)
            ->allowedFilters(['status', 'priority', 'project_id'])
            ->allowedSorts(['created_at', 'due_at', 'priority'])
            ->allowedIncludes(['project'])
            ->paginate();

        return new JsonDataResponse(
            data: $tasks->items(),
            meta: [
                'current_page' => $tasks->currentPage(),
                'per_page'     => $tasks->perPage(),
                'total'        => $tasks->total(),
                'last_page'    => $tasks->lastPage(),
            ],
        );
    }
}
```

## Show controller

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Task\V1;

use App\Http\Responses\JsonDataResponse;
use Domain\Task\Models\Task;
use Spatie\QueryBuilder\QueryBuilder;

final class ShowTaskController
{
    public function __invoke(string $task): JsonDataResponse
    {
        $task = QueryBuilder::for(Task::where('id', $task))
            ->allowedIncludes(['project'])
            ->firstOrFail();

        return new JsonDataResponse($task);
    }
}
```

## Update controller + action

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Task\V1;

use App\Http\Requests\Task\V1\UpdateTaskRequest;
use App\Http\Responses\JsonDataResponse;
use Domain\Task\Actions\UpdateTaskAction;
use Domain\Task\Models\Task;

final class UpdateTaskController
{
    public function __invoke(UpdateTaskRequest $request, Task $task): JsonDataResponse
    {
        $updated = UpdateTaskAction::make()->execute($task, $request->dto());

        return new JsonDataResponse($updated);
    }
}
```

```php
<?php

declare(strict_types=1);

namespace Domain\Task\Actions;

use Domain\Task\DTOs\UpdateTaskDTO;
use Domain\Task\Models\Task;

final readonly class UpdateTaskAction
{
    public static function make(): static
    {
        return app(static::class);
    }

    public function execute(Task $task, UpdateTaskDTO $dto): Task
    {
        $task->update($dto->toArray());

        return $task->fresh();
    }
}
```

## Destroy controller

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Task\V1;

use Domain\Task\Models\Task;
use Illuminate\Http\JsonResponse;

final class DestroyTaskController
{
    public function __invoke(Task $task): JsonResponse
    {
        $task->delete();

        return new JsonResponse(status: 204);
    }
}
```

## Response classes (`app/Http/Responses/`)

### Success

```php
<?php

declare(strict_types=1);

namespace App\Http\Responses;

use Illuminate\Contracts\Support\Responsable;
use Illuminate\Http\JsonResponse;

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

### Error

```php
<?php

declare(strict_types=1);

namespace App\Http\Responses;

use Illuminate\Contracts\Support\Responsable;
use Illuminate\Http\JsonResponse;

final readonly class JsonErrorResponse implements Responsable
{
    public function __construct(
        private string $title,
        private int $status = 400,
        private ?string $detail = null,
        private ?array $errors = null,
    ) {
    }

    public function toResponse($request): JsonResponse
    {
        $problem = [
            'type'   => 'about:blank',
            'title'  => $this->title,
            'status' => $this->status,
        ];

        if ($this->detail !== null) {
            $problem['detail'] = $this->detail;
        }

        if ($this->errors !== null) {
            $problem['errors'] = $this->errors;
        }

        return new JsonResponse(
            data: $problem,
            status: $this->status,
            headers: ['Content-Type' => 'application/problem+json'],
        );
    }
}
```

## Routes

### Main API routes file

```php
<?php

declare(strict_types=1);
// routes/api/routes.php

use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    require __DIR__ . '/tasks.php';
    require __DIR__ . '/projects.php';
});
```

### Domain routes file

```php
<?php

declare(strict_types=1);
// routes/api/tasks.php

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

// V2 (when needed) — add Sunset middleware to V1 above:
// Route::middleware(['auth:sanctum', 'http.sunset:2025-12-31'])->group(...)
```

## HTTP Sunset middleware (`app/Http/Middleware/`)

```php
<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class HttpSunset
{
    public function handle(Request $request, Closure $next, string $date): Response
    {
        $response = $next($request);

        $response->headers->set('Sunset', $date);
        $response->headers->set(
            'Deprecation',
            'This API version is deprecated and will be removed on ' . $date,
        );

        return $response;
    }
}
```

## AppServiceProvider setup

```php
<?php

declare(strict_types=1);

namespace App\Providers;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\ServiceProvider;

final class AppServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        // Prevent lazy loading and N+1 queries.
        Model::shouldBeStrict();
    }
}
```

## Exception handler (Problem+JSON, RFC 7807)

Convert exceptions — including domain exceptions — to a consistent Problem+JSON envelope. In Laravel 11+ this is configured in `bootstrap/app.php`; the shape below applies wherever you render.

```php
<?php

declare(strict_types=1);

namespace App\Exceptions;

use Domain\Task\Exceptions\InvalidStateTransition;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Throwable;

final class ApiExceptionRenderer
{
    public function render(Throwable $e): JsonResponse
    {
        $status = $this->statusFor($e);

        $problem = [
            'type'   => 'about:blank',
            'title'  => $this->titleFor($e),
            'status' => $status,
            'detail' => $e->getMessage(),
        ];

        if ($e instanceof ValidationException) {
            $problem['errors'] = $e->errors();
        }

        return new JsonResponse(
            data: $problem,
            status: $status,
            headers: ['Content-Type' => 'application/problem+json'],
        );
    }

    private function statusFor(Throwable $e): int
    {
        return match (true) {
            $e instanceof ValidationException     => 422,
            $e instanceof ModelNotFoundException  => 404,
            $e instanceof AuthenticationException => 401,
            $e instanceof InvalidStateTransition  => 409,
            $e instanceof HttpException           => $e->getStatusCode(),
            default                               => 500,
        };
    }

    private function titleFor(Throwable $e): string
    {
        return match (true) {
            $e instanceof ValidationException     => 'Validation Failed',
            $e instanceof ModelNotFoundException  => 'Resource Not Found',
            $e instanceof AuthenticationException => 'Authentication Required',
            $e instanceof InvalidStateTransition  => 'Invalid State Transition',
            $e instanceof HttpException           => $e->getMessage(),
            default                               => 'Internal Server Error',
        };
    }
}
```
