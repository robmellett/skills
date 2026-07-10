<?php

declare(strict_types=1);

namespace Domain\{Domain}\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

final class {Model} extends Model
{
    use HasFactory;
    use HasUlids;

    protected $fillable = [
        // Add fillable attributes
    ];

    protected $casts = [
        // Cast statuses/types to backed enums, dates to immutable_datetime
    ];
}
