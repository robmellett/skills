<?php

declare(strict_types=1);

namespace Domain\{Domain}\Actions;

use Domain\{Domain}\Models\{Model};
use Domain\{Domain}\Payloads\{Payload};
use Illuminate\Support\Facades\DB;

final readonly class {Verb}{Domain}Action
{
    // Compose other Actions via constructor injection — never app()/resolve().
    public function __construct() {}

    public function __invoke({Payload} $payload): {Model}
    {
        return DB::transaction(function () use ($payload) {
            // Implement the business operation (one user story).
        });
    }
}
