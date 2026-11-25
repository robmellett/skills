---
name: laravel-saloon-sdk
description: "Build a Laravel SDK for a third-party API with Saloon: connector, one request per endpoint, resources, DTOs, container binding and tests. Use when integrating or wrapping an external API, adding a Saloon connector or request, or reviewing Saloon integration code. Triggers on saloon, saloonphp, api client, api sdk, api integration, connector, wrap this api."
---

# Laravel Saloon SDK

Build API integrations as a small SDK. The app calls `$connector->resource()->method()` and gets typed DTOs back. It never creates Requests itself and never handles Saloon `Response` objects.

## Layers

| Layer | Responsibility | Must not contain |
|---|---|---|
| Connector | Base URL, auth, default headers, retries, error handling, resource accessors | Endpoint logic |
| Request | One endpoint: method, path, query, body, response to DTO mapping | Business rules, other endpoints |
| Resource | Groups related requests; picks a Request and returns a DTO | Business logic, raw arrays |
| Data (DTOs) | Typed input and output objects | HTTP concerns |

Business rules belong in the app's Actions/Services, which inject the Connector.

## Folder layout

Use the Saloon Laravel plugin default location, and group Requests by domain to match the Resources:

```
app/Http/Integrations/{Service}/
├── {Service}Connector.php
├── Resources/{Domain}Resource.php
├── Requests/{Domain}/{Verb}{Thing}Request.php
└── Data/{Thing}.php, Create{Thing}Data.php
```

Name Requests verb-first (`ListProductsRequest`, `GetProductRequest`, `CreateProductRequest`, `UpdateProductRequest`, `DeleteProductRequest`). Name Resource methods `list`, `get`, `create`, `update`, `delete`, plus domain verbs (`cancel`, `refund`) where the API has them.

## Workflow

1. **Map the API.** List the endpoints in scope and group them into domains, one Resource per domain. Note auth type, base URL, pagination style and error format.
2. **Connector.** Extend `Saloon\Http\Connector`. Use `AcceptsJson` and `AlwaysThrowOnErrors`. Inject base URL and credentials through the constructor; never call `config()` inside the connector. Implement `defaultAuth()`. Add one accessor method per Resource.
3. **DTOs.** `final readonly` classes. Output DTOs get a `static fromArray(array $data): self` named constructor. Input DTOs get `toArray(): array`.
4. **Requests.** One class per endpoint. Inputs go in constructor promotion (`private readonly`). Use `defaultQuery()` for filters/paging. For bodies, implement `HasBody` and use `HasJsonBody` (or `HasFormBody`/`HasMultipartBody`), with `defaultBody()` returning `$this->data->toArray()`. Always implement `createDtoFromResponse()`.
5. **Resources.** Extend `Saloon\Http\BaseResource`. Each method sends one Request and returns `->dtoOrFail()`. Keep methods to a line or two. For nested endpoints, return a child Resource that holds the parent ID.
6. **Bind it.** Register the Connector as a singleton in a service provider, reading `config('services.{service}.*')`. Add the config keys to `config/services.php` and `.env.example`.
7. **Tests.** Use PHPUnit. Use `MockClient::global([...])` (or `Saloon::fake()` from the Laravel plugin) keyed by Request class. Test through the Resource API, not the Requests directly. Prevent stray requests so unmocked calls fail.
8. **Pagination.** If the API paginates and callers need every page, use `saloonphp/pagination-plugin` on the Connector and have the Resource return the paginator instead of taking a `$page` argument.

## Templates

### Connector

```php
<?php

declare(strict_types=1);

namespace App\Http\Integrations\Store;

use App\Http\Integrations\Store\Resources\ProductResource;
use Saloon\Contracts\Authenticator;
use Saloon\Http\Auth\TokenAuthenticator;
use Saloon\Http\Connector;
use Saloon\Traits\Plugins\AcceptsJson;
use Saloon\Traits\Plugins\AlwaysThrowOnErrors;

final class StoreConnector extends Connector
{
    use AcceptsJson;
    use AlwaysThrowOnErrors;

    public function __construct(
        private readonly string $baseUrl,
        private readonly string $token,
    ) {}

    public function resolveBaseUrl(): string
    {
        return $this->baseUrl;
    }

    protected function defaultAuth(): ?Authenticator
    {
        return new TokenAuthenticator($this->token);
    }

    public function products(): ProductResource
    {
        return new ProductResource($this);
    }
}
```

### GET request with DTO

```php
final class GetProductRequest extends Request
{
    protected Method $method = Method::GET;

    public function __construct(private readonly int $id) {}

    public function resolveEndpoint(): string
    {
        return "/products/{$this->id}";
    }

    public function createDtoFromResponse(Response $response): Product
    {
        return Product::fromArray($response->json('data'));
    }
}
```

### List request with query

```php
final class ListProductsRequest extends Request
{
    protected Method $method = Method::GET;

    public function __construct(
        private readonly int $page = 1,
        private readonly ?string $status = null,
    ) {}

    public function resolveEndpoint(): string
    {
        return '/products';
    }

    protected function defaultQuery(): array
    {
        return array_filter(['page' => $this->page, 'status' => $this->status]);
    }

    /** @return array<int, Product> */
    public function createDtoFromResponse(Response $response): array
    {
        return array_map(Product::fromArray(...), $response->json('data'));
    }
}
```

### POST request with body

```php
final class CreateProductRequest extends Request implements HasBody
{
    use HasJsonBody;

    protected Method $method = Method::POST;

    public function __construct(private readonly CreateProductData $data) {}

    public function resolveEndpoint(): string
    {
        return '/products';
    }

    protected function defaultBody(): array
    {
        return $this->data->toArray();
    }

    public function createDtoFromResponse(Response $response): Product
    {
        return Product::fromArray($response->json('data'));
    }
}
```

### Resource

```php
final class ProductResource extends BaseResource
{
    /** @return array<int, Product> */
    public function list(int $page = 1, ?string $status = null): array
    {
        return $this->connector->send(new ListProductsRequest($page, $status))->dtoOrFail();
    }

    public function get(int $id): Product
    {
        return $this->connector->send(new GetProductRequest($id))->dtoOrFail();
    }

    public function create(CreateProductData $data): Product
    {
        return $this->connector->send(new CreateProductRequest($data))->dtoOrFail();
    }
}
```

### Binding

```php
$this->app->singleton(StoreConnector::class, fn () => new StoreConnector(
    config('services.store.url'),
    config('services.store.token'),
));
```

### Test (PHPUnit)

```php
<?php

declare(strict_types=1);

namespace Tests\Feature\Integrations\Store;

use App\Http\Integrations\Store\Requests\Products\GetProductRequest;
use App\Http\Integrations\Store\StoreConnector;
use PHPUnit\Framework\Attributes\Test;
use Saloon\Http\Faking\MockClient;
use Saloon\Http\Faking\MockResponse;
use Tests\TestCase;

final class ProductResourceTest extends TestCase
{
    #[Test]
    public function it_fetches_a_product(): void
    {
        MockClient::global([
            GetProductRequest::class => MockResponse::make(['data' => ['id' => 42, 'name' => 'Serum']]),
        ]);

        $product = $this->app->make(StoreConnector::class)->products()->get(42);

        $this->assertSame('Serum', $product->name);
    }

    protected function tearDown(): void
    {
        MockClient::destroyGlobal();

        parent::tearDown();
    }
}
```

## Error handling

`AlwaysThrowOnErrors` makes 4xx/5xx responses throw `RequestException` subclasses. If the integration needs Sentry tags/context, or exceptions that hide API details from the client, follow the `laravel-http-sentry-exceptions` skill and override `getRequestException()` on the Connector to throw the domain exceptions.

## Review checklist

- [ ] `declare(strict_types=1)`, `final` classes, readonly constructor promotion
- [ ] No long docblocks above class declarations
- [ ] No `config()` or `env()` inside Connector, Requests or Resources
- [ ] Every Request has exactly one endpoint and a `createDtoFromResponse()`
- [ ] Resource methods return DTOs (or arrays of DTOs / paginators), never `Response`
- [ ] App code depends on the Connector via the container, never `new Request(...)`
- [ ] Request bodies are built from input DTOs, not loose arrays
- [ ] PHPUnit tests mock by Request class and call through Resources; stray requests fail
- [ ] Config keys added to `config/services.php` and `.env.example`
