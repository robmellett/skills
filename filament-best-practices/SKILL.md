---
name: filament-best-practices
description: Build idiomatic, maintainable Filament v5 panels. Use when creating, editing, reviewing, or refactoring Filament resources, schemas, forms, tables, infolists, actions, pages, widgets, or relationships; when choosing which Filament primitive should represent a domain concept; or when a form(), table(), infolist(), or configure() method grows long. Covers choosing the right primitive, keeping resource code small via schema/table and component classes, building infolists that cover every model property, defaulting relationships to relation pages with sub-navigation, the exact namespaces/commands/signatures agents get wrong, and a review checklist.
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
- Activate when a model gains or changes a field and the resource's form, infolist, and table need to be kept in sync.
- Activate when building or reviewing a View page / infolist — the entry list must account for every model property.

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

A relation page **replaces** its relation manager: don't also register it in `getRelations()`. Customize it with the same `table()` and `form()` you'd use on a relation manager.

## Keep every surface in sync when a field changes
A field on the model surfaces in more than one place in a resource, and Filament won't add it for you. When you add or change a field (a new migration column, a renamed attribute, a new cast), propagate it to **every surface the resource exposes** — not just the one you were asked about:

- **Form schema** — add the input so the field can be set and edited.
- **Infolist** — add the entry so the field shows on the View page.
- **Table** — add a column (mark it `toggleable()` / hidden by default if it's secondary) so it's visible, searchable, and sortable in the list.
- **Filters** — add a filter when users will scope by the field (status, category, boolean flag, date range).

A field that exists on the model but is missing from the form, infolist, or table is the most common Filament omission. Treat "added a column" as "must appear in the form, infolist, and table" by default; leave a surface out only deliberately — e.g. a secret/token field, or an internal timestamp — and prefer that to silently forgetting it. When the definition lives in extracted schema/table/infolist classes, update those classes, not the resource.

## Infolists show the whole record
A form exposes only what's editable and a table only what's scannable, but an **infolist is the record's full detail view — default to an entry for every model property.** The habitual failure is picking "the interesting five" and dropping the rest, which leaves the View page unable to answer basic questions about the record and pushes users into the Edit page just to read data.

Enumerate the model's attributes from the model and its migrations before writing entries — never from memory, and never by copying the form:

```bash
php artisan model:show Customer
```

`model:show` lists every column with its type and cast, plus the model's relationships; that output is the checklist the infolist has to satisfy. Also check `casts()`, `$appends`, and any `Attribute` accessors — those are real properties with no column behind them.

Include:

- **Every database column** — including `id`, foreign keys, nullable columns, `created_at`/`updated_at`, and `deleted_at` when the model soft-deletes.
- **Appended and computed attributes** — `full_name`, `total`, anything in `$appends`.
- **Relationships** — a `TextEntry` on the dotted path for belongs-to (`customer.name`), a `RepeatableEntry` for a small has-many (a relation page for a large one).

Omit an entry only for a stated reason — a hashed password, an API token or secret, a raw foreign key whose related label is already shown — never because the panel felt long. When a value is sensitive but real, gate it (`->visible()`, policy check) rather than silently leaving it out.

### Length is a layout problem, not a reason to drop fields
Group entries into `Section`s by meaning and collapse the low-interest ones. A "Record" section holding `id` and the timestamps, `->collapsed()`, keeps the page tidy without losing data:

```php
use Filament\Schemas\Components\Section;

Section::make('Record')
    ->collapsed()
    ->schema([
        TextEntry::make('id')->copyable(),
        TextEntry::make('created_at')->dateTime(),
        TextEntry::make('updated_at')->dateTime()->since(),
    ]);
```

### Pick the entry from the cast
| Model cast / column type | Entry |
| --- | --- |
| `bool` | `IconEntry::make(...)->boolean()` |
| `date`, `datetime`, `immutable_datetime` | `TextEntry::make(...)->date()` / `->dateTime()` (add `->since()` for recency) |
| enum implementing `HasLabel`/`HasColor` | `TextEntry::make(...)->badge()` |
| `array`, `json`, `collection` | `KeyValueEntry` for a flat map, `RepeatableEntry` for a list of rows |
| `decimal` / money column | `TextEntry::make(...)->money('aud')` |
| `text` / `longText` | `TextEntry::make(...)->columnSpanFull()` (`->markdown()`/`->html()` when it holds rich text) |
| URL column | `TextEntry::make(...)->url(...)->openUrlInNewTab()` |
| `belongsTo` | `TextEntry::make('customer.name')` — show the label, not the raw `customer_id` |
| `hasMany`, `morphMany` | `RepeatableEntry`, or a relation page when the collection is large |
| `hashed`, token, secret | omit deliberately |

Give nullable entries a `->placeholder('—')` so an empty value still renders as a labelled row instead of a gap.

## Get the details right
These are the specifics agents most often get wrong — copy them exactly:

- **Namespaces are nested per resource.** Everything lives under `App\Filament\Resources\{PluralModel}\`: `…\Schemas`, `…\Schemas\Components`, `…\Tables\Columns`, `…\Tables\Filters`, `…\Actions`, `…\Pages`.
- **Generators**: `make:filament-resource`, `make:filament-page <Name> --resource=<Resource> --type=ManageRelatedRecords`, `make:filament-relation-manager`, `make:filament-widget`.
- **Method signatures return what they receive**: `form(Schema $schema): Schema`, `table(Table $table): Table`, `infolist(Schema $schema): Schema`; each `configure()` returns the same type it's given.
- **Icons use the `Heroicon` enum**, not strings: `use Filament\Support\Icons\Heroicon;` then `->icon(Heroicon::Envelope)`.
- **Schemas import from `Filament\Schemas\*`** (`Schema`, layout components) while fields import from `Filament\Forms\Components\*`.

## Review checklist
When reviewing Filament code, flag:

- A `form()`/`table()`/`infolist()`/`configure()` method long enough to scroll → extract to a schema/table or component class.
- A relationship managed inline under the owner's form when it warrants its own page → move to a relation page in sub-navigation.
- A component (input, column, filter, action) duplicated across resources → promote to a shared component class.
- A resource or destructive/state-changing action with no authorization → add a policy; scope queries when multi-tenant.
- A state transition implemented as a plain edit → model it as a dedicated Action.
- Icons, labels, or validation hard-coded inline where a component class would centralize them.
- A model field (new column, renamed attribute) present in one surface but missing from the others → add it to the form, infolist, and table (and a filter if users scope by it).
- An infolist that covers only some of the model's properties → run `php artisan model:show` and add the missing entries; section and collapse rather than trim.

## Core Rules (Summary)
- Decide the primitive before writing the schema; map state transitions to Actions.
- Represent relationships per the decision table; **default to relation pages with sub-navigation**, and don't register a relation page in `getRelations()`.
- Extract long `form()`/`table()`/`infolist()` definitions into schema/table classes with a static `configure(Schema|Table): Schema|Table`, called from the resource.
- Extract heavily-configured or reused components into component classes with a static `make()` factory.
- When a model field is added or changed, propagate it across every surface — form, infolist, table (and a filter where users scope by it) — not just the one in front of you.
- Build infolists from the model's full property list (`php artisan model:show`), not from the form; omit an entry only for a stated reason such as a secret or a hashed value.
- Give schema/table/component classes no parent class or interface, so `configure()`/`make()` stay free to take custom parameters.
- Place and name extracted classes per the conventions table; get namespaces, generators, signatures, and the `Heroicon` enum exactly right.
- Defer to any Boost-generated Filament guidelines already in the project.

## References
- `references/filament-code-quality-tips.md` — verbatim "Code quality tips" (schema/table classes, component classes, full `EmailCustomerAction`).
- `references/filament-managing-relationships.md` — verbatim "Choosing the right tool for the job", "Relation pages", and sub-navigation sections.
- `references/filament-ai-assisted-development.md` — verbatim "AI-assisted development" page (Laravel Boost, Filament Blueprint, Security Audit); the inspiration for this skill's shape.

## Ecosystem
- **Laravel Boost** (`composer require laravel/boost --dev`, then `php artisan boost:install`) installs Filament guidelines for implementing agents plus live doc search. Suggest it when a Filament project has no agent guidelines yet.
- **Filament Blueprint** (premium) produces detailed implementation *plans* for a planning agent to hand to an implementing agent, and ships a **Filament Security Audit** skill. See `references/filament-ai-assisted-development.md`.
