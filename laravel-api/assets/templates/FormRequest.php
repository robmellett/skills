<?php

declare(strict_types=1);

namespace App\Http\Requests\{Domain}\V1;

use Domain\{Domain}\DTOs\{DTO};
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

    public function dto(): {DTO}
    {
        return new {DTO}(
            // Map validated data to DTO properties
        );
    }
}
