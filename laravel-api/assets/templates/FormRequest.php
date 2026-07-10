<?php

declare(strict_types=1);

namespace App\Http\Requests\{Domain}\V1;

use Domain\{Domain}\Payloads\{Payload};
use Illuminate\Foundation\Http\FormRequest;

final class {Verb}{Domain}Request extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Add validation rules
        ];
    }

    public function payload(): {Payload}
    {
        return new {Payload}(
            // Map validated data to DTO properties
        );
    }
}
