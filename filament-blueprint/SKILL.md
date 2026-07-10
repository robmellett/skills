---
name: filament-blueprint
description: Produce a detailed, self-contained Filament v5 implementation plan (a "blueprint") from a feature request, for a separate implementing agent to build from. Use in planning mode when asked to plan, spec, or design a Filament feature, panel, resource, or workflow before any code is written — especially complex features with multiple models, relationships, state transitions, or authorization. Not for writing the code itself.
license: MIT
metadata:
  author: Filament
  source: https://filamentphp.com/docs/5.x/introduction/ai
---

# Filament Blueprint

## What this produces
A **blueprint**: one self-contained spec document (e.g. `BLUEPRINT.md`) that an **implementing agent** can build from directly — *without loading these planning guidelines*. The implementer should never have to guess a namespace, choose a component, or ask a clarifying question. Everything it needs is in the document.

Planning and implementing are separate jobs. This skill is the **planning agent**; it copies every exact detail — namespaces, `make:` commands, method signatures, documentation URLs to fetch — into the blueprint so the implementing agent's context stays clean.

## When to Activate
- In **planning mode**, before any code, when asked to plan / spec / design a Filament feature.
- For complex features: multiple models, relationships, state transitions, authorization, wizards, imports/exports, multi-tenancy.
- **Not** for writing the code — that's the implementing agent's job, in a fresh session.

## Prime directive: self-containment
The implementing agent will **not** have these guidelines or the Filament docs loaded. So the blueprint must inline, never hand-wave:
- Full namespaces (not "the resource namespace").
- Exact scaffold commands.
- Exact method signatures (not "a configure method").
- A documentation URL to fetch for anything non-obvious.

If a section says "see the docs," it isn't done — paste the specifics.

## Workflow
1. **Clarify until there are no TBDs.** Ask targeted questions: entities and fields, relationship types, who can do what, state transitions, edge cases, validation. A blueprint has zero open questions.
2. **Map the domain to primitives.** Each concept/flow → Resource / Relation page or manager / Page / Action / Widget. Identify every state transition (e.g. `draft → sent → paid`) and the Action that triggers it — never a raw edit.
3. **Write the blueprint** using the template below. Fill every applicable section with exact syntax.
4. **Self-review** against the checklist. The blueprint is done only when an implementer could build it blind.

## Blueprint document template
Fill each applicable section; delete the ones a feature doesn't need.

- **Overview & user flows** — each primary flow end to end (create invoice → send → record payment).
- **Models** — every attribute, cast, relationship, and enum with exact syntax.
- **Resources** — full namespace, scaffold command, model, and the schema/table class names + signatures.
- **Forms** — field components, validation rules, layout structure.
- **Tables** — columns, filters, actions, default sort.
- **Relationships** — which primitive represents each, and the relationship type. **Default to a relation page (`ManageRelatedRecords`) in sub-navigation** unless it must be inline.
- **Authorization** — plain-English policy rules that translate directly to a Policy; tenant scoping if multi-tenant.
- **Actions & state transitions** — each transition as a named Action, with guard conditions.
- **Testing** — what to test and how to verify each flow works.
- **Advanced (as needed)** — reactive fields, wizards, imports/exports, bulk actions, widgets, multi-tenancy.

### Example spec entry (the level of exactness required)
```
### Resource: OrderResource
- Namespace:  App\Filament\Resources\Orders\OrderResource
- Scaffold:   php artisan make:filament-resource Order --generate
- Model:      App\Models\Order
- Form:       App\Filament\Resources\Orders\Schemas\OrderForm
              → public static function configure(Schema $schema): Schema
- Table:      App\Filament\Resources\Orders\Tables\OrdersTable
              → public static function configure(Table $table): Table
- Pages:      index  ListOrders   '/'
              create CreateOrder  '/create'
              edit   EditOrder    '/{record}/edit'
              items  ManageOrderItems '/{record}/items'  (type: ManageRelatedRecords)
- Items relationship: HasMany → relation PAGE (not getRelations()); add to getRecordSubNavigation()
- Docs to fetch if unsure: https://filamentphp.com/docs/5.x/resources/managing-relationships#relation-pages
```

## Conventions the plan must encode (the details agents get wrong)
- **Nested namespaces** under `App\Filament\Resources\{PluralModel}\`: `…\Schemas`, `…\Schemas\Components`, `…\Tables\Columns`, `…\Tables\Filters`, `…\Actions`, `…\Pages`.
- **Generators**: `make:filament-resource`, `make:filament-page <Name> --resource=<Resource> --type=ManageRelatedRecords`, `make:filament-widget`.
- **Signatures return what they receive**: `form(Schema): Schema`, `table(Table): Table`, `infolist(Schema): Schema`.
- **Icons use the `Heroicon` enum**: `Filament\Support\Icons\Heroicon`, e.g. `Heroicon::Envelope`.
- **A relation page replaces its relation manager** — do not also register it in `getRelations()`.

## Self-review checklist — the blueprint is done when…
- Every model attribute has a type and cast.
- Every resource names its full namespace and scaffold command.
- Every relationship names its primitive **and** relationship type.
- Every destructive or state-changing action has an authorization rule.
- Every state transition maps to a named Action.
- Method signatures are given exactly, not paraphrased.
- A documentation URL is included for anything non-obvious.
- The testing section says what to test for each flow.
- **An implementing agent needs nothing beyond this document.**

## Hand-off
Implement in a **fresh session** with clean context, pointed only at the blueprint — not at this skill. The blueprint is the contract; the implementer builds it verbatim, applying the `filament-best-practices` skill's conventions as it writes code.

## Related
- `filament-best-practices` — the implementation-time companion: apply it in the fresh session when building from a blueprint.
- **Filament Security Audit** — a sibling planning-adjacent skill that scans a finished codebase against known misconfigurations and writes a per-finding remediation plan.
