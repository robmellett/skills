# Artisan Command Best Practices

## Declare Signatures with the `#[Signature]` Attribute

Use the attribute, not the `$signature` property. Don't build signatures with heredoc/nowdoc or string concatenation — they read worse and hide parse errors.

```php
#[Signature('cache:warm {--force : Skip confirmation}')]
```

## Format Multi-Part Signatures One Per Line

When a signature has more than one argument or option, put the command name on the first line, then each argument/option on its own line indented 4 spaces, with the closing `')]` on its own line. A command with zero or one argument/option may stay on a single line.

```php
#[Signature('algolia:batch-update
    {--all : Batch update every searchable model}
    {--products : Batch update Products}
    {--minutes= : How far back to look for updated records, in minutes}
')]
```

## Describe Every Argument and Option

Each argument and option gets a description after ` : `. The description is what `--help` prints, so an undescribed option is invisible to anyone who didn't write it.

## Verify the Signature Parses

After changing a signature, run `php artisan <command> --help` to confirm it parses and the descriptions render as intended.
