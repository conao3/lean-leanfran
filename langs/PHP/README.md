# PHP

[leanfran](https://github.com/conao3/lean-leanfran/blob/master/README.md) compiles embedded Lean 4 blocks and standalone Lean modules to PHP. It also translates modeled PHP functions to Lean so you can prove that they satisfy a specification. The Composer runtime requires 64-bit PHP 8.4 or later with GMP and Tokenizer.

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

## Verify a PHP function

Continue from the application directory. Save this as `src/Calc.php`. The `#[Model]` attribute links the PHP implementation to an executable Lean specification, an input condition, and a property of the result.

```php
<?php

declare(strict_types=1);

namespace App;

use Conao3\Leanfran\Lean;
use Conao3\Leanfran\Model;

#[Lean(<<<'LEAN'
    def clampSpec (x lo hi : Int) : Int := max lo (min hi x)
    def ordered (_x lo hi : Int) : Bool := lo ≤ hi
    def inRange (_x lo hi : Int) (r : Int) : Bool := lo ≤ r && r ≤ hi
    LEAN)]
final class Calc
{
    use Calc\Functions;

    #[Model(refines: 'clampSpec', requires: 'ordered', ensures: ['in_range' => 'inRange'])]
    public static function clamp(int $x, int $lo, int $hi): int
    {
        if ($x < $lo) {
            return $lo;
        }
        if ($x > $hi) {
            return $hi;
        }
        return $x;
    }
}
```

Copy the proofs into `lean/Proofs/` next to `composer.json`. Enable Packagist to install the PHP parser as a development dependency. Composer still installs the leanfran runtime from the path repository above.

```sh
mkdir -p lean/Proofs
cp ../lean-leanfran/langs/PHP/samples/verified-clamp/lean/Proofs/Calc.lean lean/Proofs/
composer config --unset repositories.packagist.org
composer require --dev --no-interaction 'nikic/php-parser:^5.9'
vendor/bin/leanfran check --leanfran-php ../lean-leanfran/result/bin/leanfran-php --require proved
```

The proof check reports both obligations as proved.

```text
App\Calc\clamp refines: proved
App\Calc\clamp in_range: proved
```

Run the property test and call the implementation.

```sh
php -r 'require "vendor/autoload.php"; Conao3\Leanfran\Verify::checkClass(App\Calc::class); echo App\Calc::clamp(12, 0, 10), PHP_EOL;'
```

```text
10
```

## Generate from a Lake project

You can also generate PHP directly from a compiled Lean module. From the application directory, build the standalone pricing sample and generate its PHP API.

```sh
(cd ../lean-leanfran/langs/PHP/samples/pricing/lean && lake build)
../lean-leanfran/result/bin/leanfran-php module generate --module-name Pricing \
  --search-path ../lean-leanfran/langs/PHP/samples/pricing/lean/.lake/build/lib/lean \
  --output-dir generated --php-namespace 'App\Lean\Pricing'
```

The PHP guide covers embedded blocks, the compiler CLI, public types, JSON Schema, Valinor, IO, and PHP function verification. [PHP guide](https://github.com/conao3/lean-leanfran/blob/master/docs/php-guide.md)
