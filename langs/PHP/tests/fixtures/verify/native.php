<?php

declare(strict_types=1);

use App\Box;
use App\Calc;
use App\Calc\Bounds;
use App\Color;
use App\Ops;

use function App\increment;

require __DIR__ . '/vendor/autoload.php';
require __DIR__ . '/src/Functions.php';

function show(mixed $value): void
{
    if (is_bool($value)) {
        echo $value ? "true\n" : "false\n";
    } else {
        echo $value, "\n";
    }
}

function outcome(callable $run, ?callable $format = null): void
{
    set_error_handler(static function (int $level, string $message): never {
        throw new ErrorException($message, severity: $level);
    });
    try {
        $value = $run();
        echo 'ok:';
        show($format === null ? $value : $format($value));
    } catch (TypeError) {
        echo "error:overflow\n";
    } catch (DivisionByZeroError) {
        echo "error:divisionByZero\n";
    } catch (ArithmeticError) {
        echo "error:arithmeticError\n";
    } catch (UnhandledMatchError) {
        echo "error:unhandledMatch\n";
    } catch (ErrorException $error) {
        if (!str_contains($error->getMessage(), 'Undefined array key')) {
            throw $error;
        }
        echo "error:undefinedIndex\n";
    } catch (\Conao3\Leanfran\ValidationError) {
        echo "error:thrown:Conao3\\Leanfran\\ValidationError\n";
    } catch (DomainException) {
        echo "error:thrown:DomainException\n";
    } finally {
        restore_error_handler();
    }
}

foreach ([[[1, 2, 3], 5], [[1, -3, 4], 0], [[1, 5, 9], 2], [[], 4]] as [$xs, $n]) {
    outcome(static fn() => Ops::loops($xs, $n));
}
outcome(static fn() => Ops::product([4, 'é']), static fn(array $pair) => implode(',', $pair));
outcome(static fn() => Ops::integers(-5, 3));
outcome(static fn() => Ops::integers(5, 0));
outcome(static fn() => Ops::integers(PHP_INT_MIN, -1));
outcome(static fn() => Ops::floats(5.0, 3.0), static fn(float $v): bool => $v === -6.0);
outcome(static fn() => Ops::floats(5.0, -0.0), static fn(float $v): bool => $v === -6.0);
show(Ops::words("A\0é猫", '🌱'));
foreach ([false, true] as $a) {
    foreach ([false, true] as $b) {
        foreach ([null, 2] as $x) {
            show(Ops::logic($a, $b, $x));
        }
    }
}
outcome(static fn() => Ops::choices(Color::Red, 2));
outcome(static fn() => Ops::choices(Color::Red, 0));
outcome(static fn() => Ops::choices(Color::Blue, 0));
outcome(static fn() => Ops::choices(Color::Blue, 1));
outcome(static fn() => Ops::indexing(2));
outcome(static fn() => Ops::indexing(-1));
outcome(static fn() => Ops::early(2));
outcome(static fn() => Ops::early(0));
outcome(static fn() => Ops::objects(new Box(1), new Bounds(-2, 5)));
outcome(static fn() => Ops::calls(12));
outcome(static fn() => increment(5));
outcome(static fn() => increment(PHP_INT_MAX));
show(Calc::clamp(12, 1, 4));
outcome(static fn() => Calc::add(3, 4));
show(Ops::order(2, 4));
show(Ops::order(4, 2));
show(Ops::nullable(null) === null);
show(Ops::nullable(1) === 3);
show(Ops::countInput(-1));

foreach ([-2, 0, 2] as $x) {
    outcome(static fn() => Ops::branchLocal($x));
}
outcome(static fn() => Ops::generated(2, 5));
outcome(static fn() => Ops::generated(5, 2));
outcome(static fn() => Ops::standalone(-4));
