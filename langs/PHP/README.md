# PHP

[leanfran](https://github.com/conao3/lean-leanfran/blob/master/README.md) compiles embedded Lean 4 blocks and standalone Lean modules to PHP. It also translates modeled PHP functions to Lean so you can prove that they satisfy a specification. The Composer runtime requires 64-bit PHP 8.4 or later with GMP and Tokenizer.

## Install

Install the compiler with Nix. Clone leanfran for the sample files and enter the development shell for PHP, Composer, and Lean.

```sh
nix profile install 'github:conao3/lean-leanfran#leanfran'
git clone https://github.com/conao3/lean-leanfran.git
cd lean-leanfran
nix develop .#php -c sh
```

Create an application next to the clone and install [conao3/leanfran from Packagist](https://packagist.org/packages/conao3/leanfran).

```sh
cd ..
mkdir pricing-php
cd pricing-php
mkdir src
```

Save this as `composer.json` so Composer can autoload the application classes.

```json
{
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
```

```sh
composer require conao3/leanfran
```

Use the compiler and `conao3/leanfran` from the same release; `leanfran` exits 255 when their versions differ.

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

Check the Lean block, generate the PHP trait and types, and run the application.

```sh
leanfran --lang php sync
php main.php
```

The application prints the width.

```text
3
```

Commit the generated files under `src/Pricing/` and `leanfran.manifest.json`. `sync` writes `.leanfran/.gitignore`, which keeps its Lake workspace out of git. In CI, `leanfran --lang php status` checks that the committed files are up to date.

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

Copy the proofs into `lean/Proofs/` next to `composer.json`. Install the PHP parser as a development dependency.

```sh
mkdir -p lean/Proofs
cp ../lean-leanfran/langs/PHP/samples/verified-clamp/lean/Proofs/Calc.lean lean/Proofs/
composer require --dev --no-interaction 'nikic/php-parser:^5.9'
leanfran --lang php check --require proved
```

The proof check reports both obligations as proved and writes `leanfran.lock`. Commit it with the manifest.

```text
App\Calc\clamp [in_range]: proved
App\Calc\clamp [refines]: proved
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
leanfran --lang php module generate --module-name Pricing \
  --search-path ../lean-leanfran/langs/PHP/samples/pricing/lean/.lake/build/lib/lean \
  --output-dir generated --php-namespace 'App\Lean\Pricing'
```

The PHP guide covers embedded blocks, the compiler CLI, public types, JSON Schema, Valinor, IO, and PHP function verification. [PHP guide](https://github.com/conao3/lean-leanfran/blob/master/docs/php-guide.md)
