<?php

declare(strict_types=1);

namespace Domain\{Domain}\Actions;

use Domain\{Domain}\Models\{Model};
use Domain\{Domain}\Payloads\{Payload};
use Illuminate\Support\Facades\DB;

final readonly class {Verb}{Domain}Action
{
    public static function make(): static
    {
        return app(static::class);
    }

    public function execute({Payload} $payload): {Model}
    {
        return DB::transaction(function () use ($payload) {
            // Implement the business operation (one user story).
        });
    }
}
