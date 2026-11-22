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
mkdir arith-php
cd arith-php
```

Save this as `composer.json`.

```json
{
    "name": "example/arith-php",
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
            "Leanfran\\Generated\\": "generated/"
        }
    }
}
```

## First Lean module

Save this as `Arith.lean`.

```lean
def sumTo (n acc : Nat) : Nat :=
  if n = 0 then acc else sumTo (n - 1) (acc + n)
```

Save this as `main.php`. Composer loads both the generated class and its runtime.

```php
<?php

declare(strict_types=1);

require __DIR__ . '/vendor/autoload.php';

echo Leanfran\Generated\LeanArith::l_sumTo(1000000, 0), "\n";
```

Install the runtime, compile the Lean module, and run the application.

```sh
composer install --no-interaction
lean -o Arith.olean Arith.lean
../lean-leanfran/result/bin/leanfran-php module generate --module-name Arith \
  --roots sumTo --search-path . --internal-only --output-file generated/LeanArith.php
php main.php
```

```text
500000500000
```

See the [PHP guide](https://github.com/conao3/lean-leanfran/blob/master/docs/php-guide.md) for CLI options, runtime values, and IO.
