# Beyond CRUD Patterns — Code Reference

## Actions

```php
declare(strict_types=1);

namespace Domain\Orders\Actions;

use Domain\Orders\DataTransferObjects\OrderData;
use Domain\Orders\Events\OrderCreated;
use Domain\Orders\Models\Order;
use Domain\Payments\Actions\CreatePaymentIntentAction;
use Illuminate\Support\Facades\DB;

final readonly class CreateOrderAction
{
    public function __construct(
        private CreatePaymentIntentAction $createPaymentIntent,
    ) {}

    public function execute(OrderData $data): Order
    {
        return DB::transaction(function () use ($data): Order {
            $order = Order::create($data->toDatabase());

            $this->createPaymentIntent->execute($order);

            OrderCreated::dispatch($order);

            return $order;
        });
    }
}
```

Guidelines:
- `final readonly`, constructor DI only, no static calls to other actions
- One public method. Multiple related operations = multiple actions
- Wrap multi-write operations in a transaction inside the action, not the controller
- Actions may dispatch events/jobs; jobs then call actions (`dispatch(fn () => app(SyncOrderAction::class)->execute($order))` or a thin job class)
- Return the domain object or a result DTO — never a Response, never `void` if the caller needs the result

## DTOs

```php
declare(strict_types=1);

namespace Domain\Orders\DataTransferObjects;

use Domain\Orders\Enums\OrderChannel;
use Spatie\LaravelData\Attributes\MapInputName;
use Spatie\LaravelData\Data;

final class OrderData extends Data
{
    public function __construct(
        public readonly string $customerEmail,
        public readonly OrderChannel $channel,
        #[MapInputName('line_items')]
        public readonly LineItemDataCollection $lineItems,
        public readonly ?string $couponCode = null,
    ) {}
}
```

- Construct from requests: `OrderData::from($request)` — the form request only validates
- Construct from external APIs with `MapInputName` / custom `from` pipes (useful for BigCommerce payloads with inconsistent casing)
- Nullable external data: make the property nullable in the DTO and null-protect at the DTO boundary, not deep in domain code
- Never pass associative arrays between layers; if you're writing `$data['foo']` in a domain class, you need a DTO

## Models

Thin model + extracted builder/collection:

```php
final class Order extends Model
{
    protected $casts = [
        'status' => OrderState::class,      // spatie/laravel-model-states
        'channel' => OrderChannel::class,   // enum cast
        'placed_at' => 'immutable_datetime',
    ];

    public function newEloquentBuilder($query): OrderQueryBuilder
    {
        return new OrderQueryBuilder($query);
    }

    public function newCollection(array $models = []): OrderCollection
    {
        return new OrderCollection($models);
    }
}
```

```php
/** @extends Builder<Order> */
final class OrderQueryBuilder extends Builder
{
    public function whereUnfulfilled(): self
    {
        return $this->whereState('status', PendingOrderState::class);
    }

    public function forChannel(OrderChannel $channel): self
    {
        return $this->where('channel', $channel);
    }
}
```

- Prefer `immutable_datetime` / `immutable_date` casts (CarbonImmutable) — avoids mutation bugs in sync pipelines
- Generic annotations (`@extends Builder<Order>`) so Larastan resolves chained calls
- No `scopeX` methods — real builder methods are typed and discoverable

## States

```php
abstract class OrderState extends State
{
    abstract public function color(): string;

    public static function config(): StateConfig
    {
        return parent::config()
            ->default(PendingOrderState::class)
            ->allowTransition(PendingOrderState::class, PaidOrderState::class, MarkOrderPaidTransition::class)
            ->allowTransition([PendingOrderState::class, PaidOrderState::class], CancelledOrderState::class);
    }
}
```

Transition classes hold side effects (notifications, inventory adjustments). Actions trigger transitions: `$order->status->transitionTo(PaidOrderState::class)`.

Use a plain backed enum instead when states carry no behavior — don't reach for model-states just for a status column.

## Enums

```php
enum OrderChannel: string
{
    case Web = 'web';
    case Pos = 'pos';
    case Marketplace = 'marketplace';

    public function label(): string
    {
        return match ($this) {
            self::Web => 'Online store',
            self::Pos => 'Point of sale',
            self::Marketplace => 'Marketplace',
        };
    }
}
```

## View Models

```php
final readonly class EditOrderViewModel
{
    public function __construct(private Order $order) {}

    public function order(): OrderData
    {
        return OrderData::from($this->order);
    }

    /** @return array<string, string> */
    public function channelOptions(): array
    {
        return collect(OrderChannel::cases())
            ->mapWithKeys(fn (OrderChannel $c) => [$c->value => $c->label()])
            ->all();
    }
}
```

## Thin Controller (the whole point)

```php
final class OrdersController
{
    public function store(CreateOrderRequest $request, CreateOrderAction $action): OrderResource
    {
        $order = $action->execute(OrderData::from($request));

        return OrderResource::make($order);
    }
}
```

If a controller method exceeds ~5 lines, logic is leaking out of the domain.
