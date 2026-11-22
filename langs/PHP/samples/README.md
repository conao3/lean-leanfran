# PHP samples

- [sum-to](sum-to) calls a generated class from PHP. The Lean function uses tail recursion to sum natural numbers, and the caller prints results on both sides of PHP's integer limit. The checked-in class runs with Composer and PHP alone.
- [greet-cli](greet-cli) uses `--main main` to turn a Lean function into a PHP command-line program. Pass it one name to print a greeting.
- [pricing](pricing) calls a typed facade with a generated discount, round-trips JSON, catches a Lean invariant violation, and prints a JSON Schema. The checked-in classes run with Composer and PHP without installing Valinor.

All projects install `conao3/leanfran` from the PHP backend directory via a Composer path repository. From the repository root, verify the samples against their `expected.txt` files.

```sh
nix develop .#php -c make -C langs/PHP samples
```

After generating the CLI with `make samples`, run it with another name from its project directory.

```sh
cd langs/PHP/samples/greet-cli
php -d auto_prepend_file=vendor/autoload.php ../../test-out/samples/LeanGreeting.php Grace
```

To run the checked-in class directly with PHP 8.4 or later, GMP and Composer, use the following commands from the repository root.

```sh
cd langs/PHP/samples/sum-to
composer install
php main.php
```

From the repository root, verify that the checked-in classes match the current compiler's output.

```sh
nix develop .#php -c make -C langs/PHP test test-pricing-sample
```

If the generated code is expected to change, review the generated PHP before copying `test-out/samples/LeanSumTo.php` to `samples/sum-to/src/_lean/`, and the PHP files from `test-out/samples/pricing/` to `samples/pricing/src/_lean/`. These paths are relative to `langs/PHP/`.
