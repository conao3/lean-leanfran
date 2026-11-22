# PHP

[leanfran](https://github.com/conao3/lean-leanfran/blob/master/README.md) compiles embedded Lean 4 blocks and standalone Lean modules to PHP. The generated code runs with Composer and 64-bit PHP 8.4 or later with GMP.

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
mkdir src
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
            "App\\": "src/"
        }
    }
}
```

## First embedded block

Save this as `src/Pricing.php`. The nowdoc contains a structure with a proof field, a function, and a theorem about that function.

```php
<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;

#[Lean(<<<'LEAN'
    structure Range where
      lo : Nat
      hi : Nat
      ok : lo ≤ hi

    def width (r : Range) : Nat := r.hi - r.lo

    theorem width_le (r : Range) : width r ≤ r.hi := by
      unfold width
      omega
    LEAN)]
final class Pricing
{
    use Pricing\Functions;
}
```

Save this as `main.php`.

```php
<?php

declare(strict_types=1);

use App\Pricing;
use App\Pricing\Range;

require __DIR__ . '/vendor/autoload.php';

echo Pricing::width(new Range(lo: 2, hi: 5)), PHP_EOL;
```

Install the runtime, check the Lean block, generate the PHP trait and types, and run the application.

```sh
composer install --no-interaction
vendor/bin/leanfran sync --leanfran-php ../lean-leanfran/result/bin/leanfran-php
php main.php
```

The application prints the width.

```text
3
```

## Generate from a Lake project

You can also generate PHP directly from a compiled Lean module. From the application directory, build the standalone pricing sample and generate its PHP API.

```sh
(cd ../lean-leanfran/langs/PHP/samples/pricing/lean && lake build)
../lean-leanfran/result/bin/leanfran-php module generate --module-name Pricing \
  --search-path ../lean-leanfran/langs/PHP/samples/pricing/lean/.lake/build/lib/lean \
  --output-dir generated --php-namespace 'App\Lean\Pricing'
```

The PHP guide covers embedded blocks, the compiler CLI, public types, JSON Schema, Valinor, and IO. [PHP guide](https://github.com/conao3/lean-leanfran/blob/master/docs/php-guide.md)
