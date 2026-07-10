---
name: filament-best-practices
description: Build idiomatic, maintainable Filament v5 panels. Use when creating, editing, reviewing, or refactoring Filament resources, schemas, forms, tables, infolists, actions, pages, widgets, or relationships; when choosing which Filament primitive should represent a domain concept; or when a form(), table(), infolist(), or configure() method grows long. Covers choosing the right primitive, keeping resource code small via schema/table and component classes, defaulting relationships to relation pages with sub-navigation, the exact namespaces/commands/signatures agents get wrong, and a review checklist.
license: MIT
metadata:
  author: Filament
  source: https://filamentphp.com/docs/5.x
---

# Filament Best Practices

## Overview
Idiomatic Filament is won at the **planning** stage, not the syntax stage: a vague plan leads to vague code. The expensive mistakes are choosing the wrong **primitive** to represent a domain concept and letting definition methods grow into giant, unreadable files. So **decide the primitive first, then keep its definition small.** This skill is the judgment layer — the decisions, defaults, and checks; the `references/` files mirror the source docs verbatim for exact syntax.

## When to Activate
- Activate when creating, editing, reviewing, or refactoring Filament resources, pages, widgets, or relation managers.
- Activate when deciding which Filament primitive (Resource, Page, Relation manager/page, Action, form component) should represent a domain concept, relationship, or state transition.
- Activate when a `form()`, `table()`, `infolist()`, or `configure()` method is long or a resource file is hard to read.
- Activate when working on Filament schemas, forms, tables, infolists, columns, filters, or actions.

## Scope
- In scope: Filament v5 resources and their schema, table, infolist, column, filter, action, and page definitions; how relationships are represented and managed.
- Out of scope: general Laravel/PHP style (use `spatie-laravel-php`), Livewire internals, custom Blade/CSS.

## Start from the project's own conventions
- If the project uses [Laravel Boost](https://laravel.com/ai/boost), a generated **Filament** section likely exists in `CLAUDE.md`/`AGENTS.md`. Read it and defer to it — this skill complements those guidelines, it does not override them.
- Treat the official Filament v5 docs as the source of truth. Boost can search them live; the `references/` files here mirror the pages this skill leans on. When a requirement is unfamiliar, fetch the doc rather than guessing.

## Decide the primitive first
Before writing a schema, map each domain concept and flow to a concrete Filament primitive, and identify state transitions and the Actions that trigger them:

- A **Resource** manages an entity's CRUD lifecycle.
- An **Action** performs a discrete operation, especially a state transition (e.g. `draft → sent → paid`). Model each transition as its own Action rather than a raw edit.
- A **Page** hosts anything that isn't standard record CRUD (dashboards, settings, a relation page).
- A **Widget** surfaces stats or charts on a dashboard or resource page.

### Representing a relationship
Choose by relationship type and the UI you want:

| You want… | Use | Relationship types |
| --- | --- | --- |
| A full CRUD table for a related collection, on its own sub-navigation page | **Relation page (`ManageRelatedRecords`) — default** | `HasMany`, `HasManyThrough`, `BelongsToMany`, `MorphMany`, `MorphToMany` |
| That same CRUD table inline under the owner's Edit/View form | Relation manager | (as above) |
| Pick from existing records (and optionally create one in a modal) | `Select` or `CheckboxList` | `BelongsTo`, `MorphTo`, `BelongsToMany` |
| Inline CRUD of a *few*-field related model inside the owner's form | `Repeater` | `HasMany`, `MorphMany` |
| Flatten one related record's fields into the owner's form | Layout component (`Section`, `Fieldset`, `Grid`) with `->relationship()` | `BelongsTo`, `HasOne`, `MorphOne` |

Full text with per-option notes: `references/filament-managing-relationships.md`.

## Keep resource code small
Filament methods define both the UI and the behaviour in a single method, so `form()`, `table()`, `infolist()`, and `configure()` methods easily grow into giant files even with clean style. Pull definitions out into dedicated classes.

### Lever 1 — Schema and table classes
Move a whole `form()`/`table()`/`infolist()` definition into a dedicated class with a static `configure()` method (Filament generates these when you scaffold a resource), then call it from the resource:

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

```php
use App\Filament\Resources\Customers\Schemas\CustomerForm;
use Filament\Schemas\Schema;

public static function form(Schema $schema): Schema
{
    return CustomerForm::configure($schema);
}
```

Do the same for `table()` (`CustomersTable::configure($table)`) and `infolist()` (`CustomerInfolist::configure($schema)`). Keep these classes with **no parent class or interface** — that is deliberate, so you can add your own parameters and reuse a class in several places with slight tweaks.

### Lever 2 — Component classes
When a `configure()` method is still long because individual components need a lot of configuration, extract each heavily-configured component into its own class with a static `make()` factory that returns the configured component:

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

Then drop `CustomerNameInput::make()` into any `->components([...])`. The same pattern covers columns, filters, and actions — an action class returns a configured `Filament\Actions\Action` from `make()` and drops into `getHeaderActions()` or a table's `recordActions()`. Full `EmailCustomerAction` example: `references/filament-code-quality-tips.md`.

### Naming and location conventions
No rules are enforced, but follow these for consistency (directories are relative to the resource):

| Component type | Directory | Naming |
| --- | --- | --- |
| Schema components | `Schemas/Components` | after the component — `CustomerNameInput`, `CustomerCountrySelect` |
| Table columns | `Tables/Columns` | component + `Column` — `CustomerNameColumn`, `CustomerCountryColumn` |
| Table filters | `Tables/Filters` | filter + `Filter` — `CustomerCountryFilter`, `CustomerStatusFilter` |
| Actions | `Actions` | action + `Action` / `BulkAction` — `EmailCustomerAction`, `UpdateCustomerCountryBulkAction` |

## Default relationships to relation pages with sub-navigation
**Always default to a relation page (`ManageRelatedRecords`) registered in the resource's sub-navigation**, rather than a relation manager embedded beneath the owner's Edit/View form. A relation page keeps managing a relationship separate from editing the owner, and lets users switch between the View/Edit page and each relation page via sub-navigation. Reach for an embedded relation manager only when the relationship must be managed inline under the owner's form.

Generate the page (no `make:filament-relation-manager` needed):

```bash
php artisan make:filament-page ManageCustomerAddresses --resource=CustomerResource --type=ManageRelatedRecords
```

Register it in `getPages()` with a record-scoped route, then add it to sub-navigation:

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
