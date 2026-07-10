---
name: filament-best-practices
description: Apply Filament v5 code-quality and resource best practices. Use when creating, editing, reviewing, or refactoring Filament resources, schemas, forms, tables, infolists, actions, or relationships, or when a form(), table(), infolist(), or configure() method grows long; covers extracting UI definitions into dedicated schema/table classes, extracting heavily-configured components (inputs, columns, filters, actions) into component classes, and managing relationships via relation pages with resource sub-navigation.
license: MIT
metadata:
  author: Filament
  source: https://filamentphp.com/docs/5.x/resources/code-quality-tips
---

# Filament Best Practices

## Overview
Filament methods define both the UI and the functionality of the app in a single method, so `form()`, `table()`, `infolist()`, and `configure()` methods easily grow into giant, hard-to-read files — even when the code style is clean. Keep resource code small and readable by **extracting** definitions out of the resource and into dedicated classes.

## When to Activate
- Activate when creating, editing, reviewing, or refactoring Filament resources, pages, or relation managers.
- Activate when a `form()`, `table()`, `infolist()`, or `configure()` method is long or a resource file is hard to read.
- Activate when working on Filament schemas, forms, tables, infolists, columns, filters, or actions.
- Activate when managing a resource's relationships — deciding between relation managers and relation pages, or wiring up sub-navigation.

## Scope
- In scope: Filament v5 resources and their schema, table, infolist, column, filter, and action definitions, plus how relationships are managed on a resource.
- Out of scope: general Laravel/PHP style (use `spatie-laravel-php`), Livewire internals, custom Blade/CSS.

## Two levers

### 1. Schema and table classes
Move a whole `form()`, `table()`, or `infolist()` definition into a dedicated class with a static `configure()` method, then call it from the resource. Filament generates these classes when you generate a resource.

```php
namespace App\Filament\Resources\Customers\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;

class CustomerForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name'),
                // ...
            ]);
    }
}
```

Call it from the resource:

```php
use App\Filament\Resources\Customers\Schemas\CustomerForm;
use Filament\Schemas\Schema;

public static function form(Schema $schema): Schema
{
    return CustomerForm::configure($schema);
}
```

Do the same for `table()` (e.g. `CustomersTable::configure($table)`) and `infolist()` (e.g. `CustomerInfolist::configure($schema)`).

Keep these classes with **no parent class or interface**. That is deliberate: without an enforced `configure()` signature you can add your own parameters and reuse the same class in multiple places with slight tweaks.

### 2. Component classes
When a `configure()` method is still long — often because individual components need a lot of configuration — extract each heavily-configured component into its own class with a static `make()` factory that returns the configured component.

```php
namespace App\Filament\Resources\Customers\Schemas\Components;

use Filament\Forms\Components\TextInput;

class CustomerNameInput
{
    public static function make(): TextInput
    {
        return TextInput::make('name')
            ->label('Full name')
            ->required()
            ->maxLength(255)
            ->placeholder('Enter your full name')
            ->belowContent('This is the name that will be displayed on your profile.');
    }
}
```

Use it wherever the component is expected:

```php
use App\Filament\Resources\Customers\Schemas\Components\CustomerNameInput;
use Filament\Schemas\Schema;

public static function configure(Schema $schema): Schema
{
    return $schema
        ->components([
            CustomerNameInput::make(),
            // ...
        ]);
}
```

The same pattern works for columns, filters, and actions. An action class returns a configured `Filament\Actions\Action` from `make()` and drops into `getHeaderActions()` on a page or `recordActions()` on a table. See `references/filament-code-quality-tips.md` for the full `EmailCustomerAction` example.

## Naming and location conventions
No rules are enforced, but follow these conventions for consistency (all directories are relative to the resource):

| Component type | Directory | Naming |
| --- | --- | --- |
| Schema components | `Schemas/Components` | after the component — `CustomerNameInput`, `CustomerCountrySelect` |
| Table columns | `Tables/Columns` | component + `Column` — `CustomerNameColumn`, `CustomerCountryColumn` |
| Table filters | `Tables/Filters` | filter + `Filter` — `CustomerCountryFilter`, `CustomerStatusFilter` |
| Actions | `Actions` | action + `Action` / `BulkAction` — `EmailCustomerAction`, `UpdateCustomerCountryBulkAction` |

## Managing relationships: default to relation pages with sub-navigation

**Always default to a relation page (`ManageRelatedRecords`) registered in the resource's sub-navigation**, rather than a relation manager embedded beneath the owner's Edit/View form. A relation page keeps managing a relationship separate from editing or viewing the owner record, and lets users switch between the View/Edit page and each relation page via sub-navigation. Reach for an embedded relation manager only when you specifically want the relationship managed inline under the owner's form.

Generate the page (no `make:filament-relation-manager` needed):

```bash
php artisan make:filament-page ManageCustomerAddresses --resource=CustomerResource --type=ManageRelatedRecords
```

Register it in `getPages()` with a record-scoped route:

```php
public static function getPages(): array
{
    return [
        'index' => Pages\ListCustomers::route('/'),
        'create' => Pages\CreateCustomer::route('/create'),
        'view' => Pages\ViewCustomer::route('/{record}'),
        'edit' => Pages\EditCustomer::route('/{record}/edit'),
        'addresses' => Pages\ManageCustomerAddresses::route('/{record}/addresses'),
    ];
}
```

Add it to the resource sub-navigation:

```php
use App\Filament\Resources\Customers\Pages;
use Filament\Resources\Pages\Page;

public static function getRecordSubNavigation(Page $page): array
{
    return $page->generateNavigationItems([
        // ...
        Pages\ManageCustomerAddresses::class,
    ]);
}
```

You do not need to generate a relation manager or register it in `getRelations()`. Customize the page with the same `table()` and `form()` you would use on a relation manager.

## Core Rules (Summary)
- Extract long `form()`/`table()`/`infolist()` definitions into dedicated schema/table classes with a static `configure(Schema|Table): Schema|Table` method, and call them from the resource (`CustomerForm::configure($schema)`).
- Extract heavily-configured components into component classes with a static `make()` factory that returns the configured component.
- Don't give schema/table/component classes a parent class or interface — keep `configure()`/`make()` free to take custom parameters for reuse.
- Place and name extracted classes per the conventions table above.
- Default to relation pages (`ManageRelatedRecords`) with resource sub-navigation for managing relationships; use an embedded relation manager only when the relationship must be managed inline under the owner's form.

## References
- `references/filament-code-quality-tips.md` — full verbatim Filament "Code quality tips" documentation with every code example.
- `references/filament-relation-pages.md` — full verbatim "Relation pages" and sub-navigation sections of Filament's "Managing relationships" documentation.
