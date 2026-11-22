# leanfran for PHP

Generate PHP 8.4 code from Lean 4 modules. The generated classes use the Composer runtime and run on 64-bit PHP with GMP.

From the repository root, build the compiler and enter the PHP development shell.

~~~sh
nix build .#php
nix develop .#php
cd langs/PHP
composer install
~~~

Save this definition as Arith.lean in the PHP backend directory.

~~~lean
def sumTo (n acc : Nat) : Nat :=
  if n = 0 then acc else sumTo (n - 1) (acc + n)
~~~

Compile the Lean module, generate its PHP class, and call the function.

~~~sh
lean -o Arith.olean Arith.lean
../../result/bin/leanfran-php module generate --module-name Arith \
  --search-path . --internal-only --output-file gen/LeanArith.php
php -r 'require "vendor/autoload.php"; require "gen/LeanArith.php"; echo \Leanfran\Generated\LeanArith::l_sumTo(1000000, 0), "\n";'
# 500000500000
~~~
