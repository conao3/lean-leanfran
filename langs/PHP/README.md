# PHP

[leanfran](https://github.com/conao3/lean-leanfran/blob/master/README.md) compiles Lean 4 modules into PHP classes. The generated code runs with Composer and 64-bit PHP 8.4 or later with GMP.

## Install

From an empty working directory, set `LEANFRAN_SOURCE` to a local checkout of the PHP backend or the Git URL of a repository whose default branch contains it. Clone the source, build the compiler, and enter the PHP development shell.

```sh
git clone "$LEANFRAN_SOURCE" lean-leanfran
cd lean-leanfran
nix build .#php
nix develop .#php -c sh
```

Create an application next to the clone. The Composer path repository points to the runtime in that clone.

```sh
cd ..
mkdir pricing-php
cd pricing-php
```

Save this as `composer.json`.

```json
{
    "name": "example/pricing-php",
    "require": {
        "conao3/leanfran": "dev-main"
    },
    "repositories": [
        {
            "type": "path",
            "url": "../lean-leanfran/langs/PHP",
            "options": {
                "versions": {
                    "conao3/leanfran": "dev-main"
                },
                "reference": "config"
            }
        },
        {
            "packagist.org": false
        }
    ],
    "autoload": {
        "psr-4": {
            "App\\Lean\\Pricing\\": "generated/"
        }
    }
}
```

## First Lean module

Save this as `Pricing.lean`.

```lean
namespace Pricing

structure Range where
  lo : Nat
  hi : Nat
  ok : lo ≤ hi

inductive Discount where
  | none
  | percent (p : Nat) (h : p ≤ 100)
  | fixed (amount : Nat)

def total (prices : List Nat) (discount : Discount) : Nat :=
  let subtotal := prices.foldl (· + ·) 0
  match discount with
  | .none => subtotal
  | .percent p _ => subtotal - subtotal * p / 100
  | .fixed amount => subtotal - amount

end Pricing
```

Save this as `main.php`. Composer loads the generated types, function facade, and runtime.

```php
<?php

declare(strict_types=1);

use App\Lean\Pricing\DiscountPercent;
use App\Lean\Pricing\Pricing;
use App\Lean\Pricing\Range;
use Conao3\Leanfran\ValidationError;

require __DIR__ . '/vendor/autoload.php';

echo Pricing::total([1200, 800], new DiscountPercent(10)), PHP_EOL;
echo Range::fromJson('{"lo":1,"hi":3}')->toJson(), PHP_EOL;

try {
    new Range(lo: 5, hi: 3);
} catch (ValidationError $error) {
    echo $error->getMessage(), PHP_EOL;
}
```

Install the runtime, compile the Lean module, and run the application.

```sh
composer install --no-interaction
lean -o Pricing.olean Pricing.lean
../lean-leanfran/result/bin/leanfran-php module generate --module-name Pricing \
  --search-path . --output-dir generated --php-namespace 'App\Lean\Pricing' --facade Pricing
php main.php
```

The final command prints the total, the JSON value, and the validation message.

```text
1800
{"lo":1,"hi":3}
Range.ok: lo ≤ hi
```

The PHP guide covers the CLI, public types, JSON Schema, Valinor, and IO. [PHP guide](https://github.com/conao3/lean-leanfran/blob/master/docs/php-guide.md)
