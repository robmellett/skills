# Testing Beyond CRUD Code (Pest)

## Layout mirrors the source split

```
tests/
├── Domain/Orders/
│   ├── Actions/CreateOrderActionTest.php
│   ├── DataTransferObjects/OrderDataTest.php
│   └── States/OrderStateTest.php
└── App/Api/Orders/
    └── OrdersControllerTest.php     # feature tests, HTTP layer
```

## Actions: test directly, no HTTP

```php
it('creates an order and dispatches the event', function () {
    Event::fake([OrderCreated::class]);

    $data = OrderData::from([
        'customerEmail' => 'rob@example.com',
        'channel' => 'web',
        'line_items' => [['sku' => 'ABC', 'qty' => 2]],
    ]);

    $order = app(CreateOrderAction::class)->execute($data);

    expect($order)
        ->customer_email->toBe('rob@example.com')
        ->status->toBeInstanceOf(PendingOrderState::class);

    Event::assertDispatched(OrderCreated::class);
});
```

- Resolve actions via `app()` so constructor DI works; swap collaborators with `$this->mock(CreatePaymentIntentAction::class)` when isolating
- Test factories should produce valid DTOs, not arrays — add a `DataFactory` or named constructor per DTO for test setup if payloads get large

## DTOs: test the mapping, especially external payloads

```php
it('maps a BigCommerce webhook payload', function () {
    $data = OrderData::from(json_decode(file_get_contents(
        __DIR__.'/fixtures/bigcommerce-order.json',
    ), true));

    expect($data->lineItems)->toHaveCount(3);
});
```

Keep real captured payloads as fixtures — regressions in third-party casing/nullability show up here first.

## States: assert allowed and forbidden transitions

```php
it('cannot transition paid to pending', function () {
    $order = Order::factory()->create(['status' => PaidOrderState::class]);

    $order->status->transitionTo(PendingOrderState::class);
})->throws(TransitionNotFound::class);
```

## Feature tests stay shallow

Controller tests assert status codes, resource shape, and authorization — not business rules (those live in domain unit tests). One happy path + auth/validation failures is usually enough per endpoint.

```php
it('stores an order', function () {
    $response = $this->postJson(route('api.orders.store'), $payload)
        ->assertCreated()
        ->assertJsonPath('data.channel', 'web');
});
```

## Architecture tests

Enforce the layer rule mechanically:

```php
arch('domain does not depend on app layer')
    ->expect('Domain')
    ->not->toUse('App');

arch('actions are final and readonly')
    ->expect('Domain\*\Actions')
    ->toBeFinal()
    ->toBeReadonly();

arch('controllers do not use models directly for writes')
    ->expect('App\*\Controllers')
    ->not->toUse(['Illuminate\Support\Facades\DB']);
```
