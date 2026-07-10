# Filament: Relation Pages (Reference)

Source: <https://filamentphp.com/docs/5.x/resources/managing-relationships#relation-pages> (Filament v5.x)

Full content of the "Relation pages" and "Adding relation pages to resource sub-navigation" sections of Filament's "Managing relationships" documentation, reproduced for offline reference.

## Relation pages

Using a `ManageRelatedRecords` page is an alternative to using a relation manager, if you want to keep the functionality of managing a relationship separate from editing or viewing the owner record.

This feature is ideal if you are using [resource sub-navigation](https://filamentphp.com/docs/5.x/resources/overview#resource-sub-navigation), as you are easily able to switch between the View or Edit page and the relation page.

To create a relation page, you should use the `make:filament-page` command:

```bash
php artisan make:filament-page ManageCustomerAddresses --resource=CustomerResource --type=ManageRelatedRecords
```

When you run this command, you will be asked a series of questions to customize the page, for example, the name of the relationship and its title attribute.

You must register this new page in your resource's `getPages()` method:

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

> **Warning:** When using a relation page, you do not need to generate a relation manager with `make:filament-relation-manager`, and you do not need to register it in the `getRelations()` method of the resource.

Now, you can customize the page in exactly the same way as a relation manager, with the same `table()` and `form()`.

### Adding relation pages to resource sub-navigation

If you're using [resource sub-navigation](https://filamentphp.com/docs/5.x/resources/overview#resource-sub-navigation), you can register this page as normal in `getRecordSubNavigation()` of the resource:

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
