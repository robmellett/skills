<?php

declare(strict_types=1);

namespace Domain\{Domain}\Actions;

use Domain\{Domain}\DTOs\{DTO};
use Domain\{Domain}\Models\{Model};
use Illuminate\Support\Facades\DB;

final readonly class {Verb}{Domain}Action
{
    public static function make(): static
    {
        return app(static::class);
    }

    public function execute({DTO} $dto): {Model}
    {
        return DB::transaction(function () use ($dto) {
            // Implement the business operation (one user story).
        });
    }
}
