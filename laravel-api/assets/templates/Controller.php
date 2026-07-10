<?php

declare(strict_types=1);

namespace App\Http\Controllers\{Domain}\V1;

use App\Http\Requests\{Domain}\V1\{Request};
use App\Http\Responses\JsonDataResponse;
use Domain\{Domain}\Actions\{Verb}{Domain}Action;

final class {Verb}{Domain}Controller
{
    public function __invoke({Request} $request, {Verb}{Domain}Action $action): JsonDataResponse
    {
        $result = $action($request->payload());

        return new JsonDataResponse($result, status: 201);
    }
}
