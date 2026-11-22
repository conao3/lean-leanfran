#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/../.."

lean_version=$(sed 's/.*://' lean-toolchain)
if command -v lean >/dev/null && command -v leanc >/dev/null; then
  lean=$(command -v lean)
  leanc=$(command -v leanc)
else
  lean="$HOME/.elan/toolchains/leanprover--lean4---$lean_version/bin/lean"
  leanc="$(dirname "$lean")/leanc"
fi
if [[ $("$lean" --version) != "Lean (version ${lean_version#v},"* ]]; then
  printf 'Expected %s from %s\n' "$lean_version" "$lean" >&2
  exit 1
fi

php_args=(-n -d extension=gmp)
if php -n -r 'exit(extension_loaded("gmp") ? 0 : 1);'; then
  php_args=(-n)
elif ! php "${php_args[@]}" -r 'exit(extension_loaded("gmp") ? 0 : 1);' >/dev/null 2>&1; then
  gmp=$(php -r '
    $files = preg_split("/,\s*/", php_ini_scanned_files() ?: "", -1, PREG_SPLIT_NO_EMPTY);
    if ($loaded = php_ini_loaded_file()) {
        array_unshift($files, $loaded);
    }
    foreach ($files as $file) {
        if (preg_match("~^extension\s*=\s*\"?(/[^\"\r\n]+/gmp\.so)\"?\s*$~m", file_get_contents(trim($file)), $match)) {
            echo $match[1];
            exit;
        }
    }
    fwrite(STDERR, "Could not locate the PHP GMP extension.\n");
    exit(1);
  ')
  php_args=(-n -d "extension=$gmp")
fi

tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT

"$lean" --stdin > "$tmp/externs.tsv" <<'LEAN'
import Lean
open Lean

unsafe def numericExterns : IO Unit := do
  enableInitializersExecution
  let env ← importModules #[{module := `Init}] {} (loadExts := true)
  let types := ["Nat", "Int", "UInt8", "UInt16", "UInt32", "UInt64", "USize",
    "Int8", "Int16", "Int32", "Int64", "ISize", "Float", "Float32", "Bool", "Char"]
  for (name, info) in env.constants.toList.mergeSort (fun a b => a.1.toString ≤ b.1.toString) do
    if types.contains (name.toString.splitOn ".").head! then
      if let some symbol := getExternNameFor env `c name then
        IO.println s!"{name}\t{symbol}\t{info.type}"
#eval numericExterns
LEAN

cat > "$tmp/test.php" <<'PHP'
<?php

declare(strict_types=1);

use Conao3\Leanfran\Runtime as L;

const RUNTIME = 'Conao3\Leanfran\Runtime\\';
const RANDOM_CASES = 2000;
const SEED = 20261121;
const FLOAT32_ULP = [
    'sinf', 'cosf', 'tanf', 'asinf', 'acosf', 'atanf', 'atan2f', 'sinhf',
    'coshf', 'tanhf', 'asinhf', 'acoshf', 'atanhf', 'expf', 'exp2f',
    'logf', 'log2f', 'log10f', 'powf', 'cbrtf',
];
const FLOAT64_ULP = ['exp2', 'log2'];

$root = $argv[1];
$dir = $argv[2];
foreach (['object', 'string', 'io', 'nat', 'int', 'uint', 'sint', 'float'] as $file) {
    require "$root/langs/PHP/src/Runtime/$file.php";
}
set_error_handler(static function (int $severity, string $message, string $file, int $line): never {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

function cases(string $dir): array
{
    $externs = [];
    $cases = [];
    foreach (file("$dir/externs.tsv", FILE_IGNORE_NEW_LINES) as $row) {
        [$name, $symbol, $signature] = explode("\t", $row, 3);
        $externs[$symbol] = true;
        [$owner, $method] = explode('.', $name, 2);
        if (in_array($method, ['gcd._unary', 'powMod._unary', 'ofModel', 'toModel', 'toBitVec'], true)) {
            continue;
        }
        $case = $symbol;
        $function = $name;
        if (in_array($method, ['ofNatLT', 'ofNat32'], true)) {
            $case .= "@$name";
            $inputs = [$method === 'ofNat32' ? 'BoundedUInt32' : "Bounded$owner"];
            $output = $owner;
        } elseif ($owner === 'Char') {
            $case .= "@$name";
            $function = 'charOfNat';
            $inputs = ['ValidChar'];
            $output = 'Nat';
        } elseif (isset($cases[$case])) {
            continue;
        } elseif ($method === 'divExact') {
            $function = strtolower($owner) . 'DivExact';
            $inputs = [$owner, $owner];
            $output = $owner;
        } elseif (str_starts_with($method, 'dec')) {
            $inputs = $method === 'decNonneg' ? [$owner] : [$owner, $owner];
            $output = 'Decidable';
        } elseif ($method === 'ofBitVec') {
            $inputs = ["Bits$owner"];
            $output = $owner;
        } elseif ($method === 'frExp') {
            $inputs = [$owner];
            $output = $owner . 'Pair';
        } else {
            $types = explode(' -> ', str_replace(['([mdata borrowed:1 Nat])', '([mdata borrowed:1 Int])'], ['Nat', 'Int'], $signature));
            $output = array_pop($types);
            $inputs = $types;
        }
        $cases[$case] = [$symbol, $function, $inputs, $output];
    }
    if ($externs === []) {
        throw new RuntimeException('The Init extern inventory is empty.');
    }
    $functions = array_fill_keys(get_defined_functions()['user'], true);
    $missing = array_diff(array_keys($externs), array_keys(array_filter(
        $cases,
        static fn (array $case, string $key): bool => $case[0] === $key,
        ARRAY_FILTER_USE_BOTH,
    )));
    foreach ($externs as $symbol => $_) {
        if (!isset($functions[strtolower(RUNTIME . $symbol)])) {
            $missing[] = $symbol;
        }
    }
    if ($missing !== []) {
        throw new RuntimeException('Missing numeric extern or oracle case: ' . implode(', ', array_unique($missing)));
    }
    return [$externs, $cases + [
        'lean_cstr_to_nat' => ['lean_cstr_to_nat', 'String.toNat!', ['DecimalNat'], 'Nat'],
        'lean_cstr_to_int' => ['lean_cstr_to_int', 'String.toInt!', ['DecimalInt'], 'Int'],
        'lean_nat_repr' => ['lean_nat_repr', 'toString', ['Nat'], 'String'],
        'lean_int_repr' => ['lean_int_repr', 'toString', ['Int'], 'String'],
        'lean_nat_succ' => ['lean_nat_succ', 'Nat.succ', ['Nat'], 'Nat'],
        'lean_int_to_nat' => ['lean_int_to_nat', 'Int.toNat', ['Int'], 'Nat'],
        'lean_int_pow' => ['lean_int_pow', 'HPow.hPow', ['Int', 'Nat'], 'Int'],
        'lean_int_shift_right' => ['lean_int_shift_right', 'Int.shiftRight', ['Int', 'Nat'], 'Int'],
        'lean_float_of_nat' => ['lean_float_of_nat', 'Float.ofNat', ['Nat'], 'Float'],
        'lean_float32_of_nat' => ['lean_float32_of_nat', 'Float32.ofNat', ['Nat'], 'Float32'],
        'lean_float_of_int' => ['lean_float_of_int', 'Float.ofInt', ['Int'], 'Float'],
        'lean_float32_of_int' => ['lean_float32_of_int', 'Float32.ofInt', ['Int'], 'Float32'],
        'lean_float_of_scientific' => ['lean_float_of_scientific', 'Float.ofScientific', ['Nat', 'Bool', 'Nat'], 'Float'],
        'lean_float32_of_scientific' => ['lean_float32_of_scientific', 'Float32.ofScientific', ['Nat', 'Bool', 'Nat'], 'Float32'],
    ]];
}

function fixedWidth(string $type): int
{
    return match (preg_replace('/^(Bits|Bounded)/', '', $type)) {
        'Int8', 'UInt8' => 8,
        'Int16', 'UInt16' => 16,
        'Int32', 'UInt32' => 32,
        'Int64', 'UInt64', 'USize', 'ISize' => 64,
        default => 0,
    };
}

function leanInput(string $type, string $var): string
{
    $nat = "($var.toNat!)";
    $int = "($var.toInt!)";
    return match ($type) {
        'DecimalNat', 'DecimalInt' => $var,
        'Nat', 'ValidChar' => $nat,
        'Int' => $int,
        'Bool' => "(bool $var)",
        'Float' => "(float $var)",
        'Float32' => "(float32 $var)",
        default => match (true) {
            str_starts_with($type, 'Bounded') => $nat,
            $type === 'BitsUSize' => "(BitVec.ofNat System.Platform.numBits $nat)",
            str_starts_with($type, 'Bits') => '(BitVec.ofNat ' . fixedWidth($type) . " $nat)",
            str_starts_with($type, 'U') => "($type.ofNat $nat)",
            fixedWidth($type) !== 0 => "($type.ofInt $int)",
            default => throw new LogicException("Unknown Lean input type $type"),
        },
    };
}

function leanOutput(string $type, string $call): string
{
    return match ($type) {
        'Bool' => "showBool ($call)",
        'Decidable' => "showBool (decision ($call))",
        'Float' => "showFloat ($call)",
        'Float32' => "showFloat32 ($call)",
        'FloatPair' => "showFloatPair ($call)",
        'Float32Pair' => "showFloat32Pair ($call)",
        'String' => $call,
        'Nat', 'Int' => "toString ($call)",
        default => match (true) {
            str_starts_with($type, 'U') => "toString (($call).toNat)",
            fixedWidth($type) !== 0 => "toString (($call).toInt)",
            default => throw new LogicException("Unknown Lean output type $type"),
        },
    };
}

function generateDispatch(string $dir, array $cases): void
{
    $file = fopen("$dir/NumericDispatch.lean", 'w');
    fwrite($file, "import LeanPhpTest.NumericOracleMain\n\nset_option maxHeartbeats 0\nset_option maxRecDepth 4096\n\nnamespace NumericOracle\n\n");
    $dispatch = [];
    foreach ($cases as $key => [$symbol, $name, $inputs, $output]) {
        $vars = array_slice(['a', 'b', 'c'], 0, count($inputs));
        $args = implode(' ', array_map(leanInput(...), $inputs, $vars));
        $call = "$name $args";
        if (str_contains($key, '@') && str_starts_with($inputs[0], 'Bounded')) {
            $proofBound = $name === 'USize.ofNat32' ? '(2 ^ 32)' : "$output.size";
            $call = "if h : $args < $proofBound then $call h else panic! \"invalid $name input\"";
        }
        $wrapper = 'run_' . count($dispatch);
        $binders = implode(' ', $vars);
        fwrite($file, "def $wrapper ($binders : String) : String :=\n  " . leanOutput($output, $call) . "\n\n");
        $dispatch[] = "  | [\"$key\", " . implode(', ', $vars) . "] => some ($wrapper $binders)\n";
    }
    fwrite($file, "def dispatch : List String → Option String\n" . implode('', $dispatch));
    fwrite($file, "  | _ => none\n\nend NumericOracle\n\ndef main : IO Unit := NumericOracle.run NumericOracle.dispatch\n");
    fclose($file);
}

function fitsIntWidth(GMP $value, int $width, bool $signed): bool
{
    if ($width === 0) {
        return $signed || gmp_sign($value) >= 0;
    }
    $limit = gmp_init(1) << ($width - (int) $signed);
    return gmp_cmp($value, $signed ? gmp_neg($limit) : 0) >= 0 && gmp_cmp($value, $limit) < 0;
}

function integerBounds(int $width, bool $signed): array
{
    $values = ['0', '1', '2', '3'];
    if ($width === 0 || ($width === 64 && !$signed)) {
        array_push($values, '4611686293305294848', '4611686293305294849');
    }
    foreach ([7, 8, 15, 16, 23, 24, 31, 32, 53, 63, 64] as $shift) {
        $power = gmp_init(1) << $shift;
        foreach ([-1, 0, 1] as $delta) {
            $positive = gmp_add($power, $delta);
            $negative = gmp_neg($positive);
            if (fitsIntWidth($positive, $width, $signed)) {
                $values[] = gmp_strval($positive);
            }
            if ($signed && fitsIntWidth($negative, $width, true)) {
                $values[] = gmp_strval($negative);
            }
        }
    }
    if ($signed) {
        array_push($values, '-1', '-2', '-3');
    }
    return array_values(array_unique($values));
}

function floatBounds(bool $single): array
{
    $values = [];
    foreach ([0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 6.0, 10.0, 24.0, 127.0, 128.0, 149.0, 150.0, 255.0, 256.0, 65536.0, 2147483648.0,
        9223372036854775808.0, 18446744073709551616.0, 0.0078125, INF, NAN] as $value) {
        $bits = unpack($single ? 'V' : 'P', pack($single ? 'g' : 'e', $value))[1];
        foreach ([$bits, $bits | ($single ? 0x80000000 : PHP_INT_MIN)] as $signed) {
            $values[] = sprintf('%u', $signed);
        }
    }
    $extra = $single
        ? ['00000001', '80000001', '007fffff', '807fffff', '00800000', '80800000', '7f7fffff', 'ff7fffff',
            '7f800001', 'ff800001', '3effffff', '3f000001', '3f7fffff', '3f800001', 'd4350b28']
        : ['0000000000000001', '8000000000000001', '000fffffffffffff', '800fffffffffffff',
            '0010000000000000', '8010000000000000', '7fefffffffffffff', 'ffefffffffffffff',
            '7ff0000000000001', 'fff0000000000001', '3fdfffffffffffff', '3fe0000000000001',
            '3fefffffffffffff', '3ff0000000000001', '9508b92445a1549c',
            '4081e91440000000', '3ffffeb9c0000000'];
    return array_values(array_unique(array_merge($values, array_map(
        static fn (string $bits): string => gmp_strval(gmp_init($bits, 16)),
        $extra,
    ))));
}

function bounds(string $type): array
{
    static $cache = [];
    return $cache[$type] ??= match ($type) {
        'Float' => floatBounds(false),
        'Float32' => floatBounds(true),
        'Bool' => ['0', '1'],
        'ValidChar' => ['0', '1', '127', '128', '55295', '57344', '65535', '65536', '1114111'],
        'Nat', 'DecimalNat' => integerBounds(0, false),
        'Int', 'DecimalInt' => integerBounds(0, true),
        default => integerBounds(fixedWidth($type), str_starts_with($type, 'I')),
    };
}

function sampleBits(int $width): string
{
    static $counter = 0;
    return substr(hash('sha256', pack('V2', SEED, $counter++)), 0, intdiv($width, 4));
}

function randomOperand(string $type, int $index): string
{
    if ($type === 'Bool') {
        return (string) (hexdec(sampleBits(4)) & 1);
    }
    if ($type === 'ValidChar') {
        $codepoint = hexdec(sampleBits(24)) % (0x110000 - 0x800);
        return (string) ($codepoint < 0xd800 ? $codepoint : $codepoint + 0x800);
    }
    if ($type === 'Float' || $type === 'Float32') {
        $single = $type === 'Float32';
        if ($index % 3 === 0) {
            $value = (hexdec(sampleBits(24)) - 0x800000) / 8192.0;
            return sprintf('%u', unpack($single ? 'V' : 'P', pack($single ? 'g' : 'e', $value))[1]);
        }
        if ($index % 3 === 1) {
            $value = (hexdec(sampleBits(24)) - 0x800000) / 4194304.0;
            return sprintf('%u', unpack($single ? 'V' : 'P', pack($single ? 'g' : 'e', $value))[1]);
        }
        return gmp_strval(gmp_init(sampleBits($single ? 32 : 64), 16));
    }
    $width = fixedWidth($type);
    if ($width === 0) {
        $width = [8, 32, 64, 128, 256][$index % 5];
    }
    $value = gmp_init(sampleBits($width), 16);
    if (($type === 'DecimalInt' || str_starts_with($type, 'I')) && gmp_testbit($value, $width - 1)) {
        $value = gmp_sub($value, gmp_init(1) << $width);
    }
    return gmp_strval($value);
}

function products(array $inputs): Generator
{
    if ($inputs === []) {
        yield [];
        return;
    }
    $first = array_shift($inputs);
    foreach (products($inputs) as $tail) {
        foreach ($first as $value) {
            yield [$value, ...$tail];
        }
    }
}

function inputBounds(string $symbol, array $types): array
{
    $inputs = array_map(bounds(...), $types);
    if (in_array($symbol, ['lean_nat_pow', 'lean_int_pow', 'lean_nat_powmod', 'lean_nat_shiftl'], true)) {
        $inputs[1] = array_values(array_unique(array_merge($inputs[1], [
            '63', '64', '65', '127', '128', '149', '255', '256', '1024', '4294967296',
        ])));
    }
    if (str_ends_with($symbol, '_of_scientific')) {
        $inputs[2] = array_values(array_unique(array_merge($inputs[2], ['22', '23', '38', '45', '46', '308', '309', '324', '325'])));
    }
    return $inputs;
}

function exactDiv(string $symbol): bool
{
    return in_array($symbol, ['lean_int_div_exact', 'lean_nat_div_exact'], true);
}

function unsafeResultSize(string $symbol, array $args): bool
{
    if ($symbol === 'lean_nat_powmod' && $args[2] !== '0') {
        return false;
    }
    if (!in_array($symbol, ['lean_nat_pow', 'lean_nat_powmod', 'lean_int_pow', 'lean_nat_shiftl'], true)) {
        return false;
    }
    if ($args[0] === '0' || ($symbol !== 'lean_nat_shiftl' && in_array($args[0], ['-1', '1'], true))) {
        return false;
    }
    return gmp_cmp($args[1], 1024) > 0;
}

function panicCase(string $symbol, array $args): bool
{
    return $symbol !== 'lean_int_pow' && unsafeResultSize($symbol, $args) && gmp_cmp($args[1], '4294967295') > 0;
}

function rows(string $symbol, array $types, string $target, mixed $panic): Generator
{
    foreach (products(inputBounds($symbol, $types)) as $args) {
        if (exactDiv($symbol) && ($args[1] === '0' || gmp_cmp(gmp_mod($args[0], $args[1]), 0) !== 0)) {
            continue;
        }
        if (unsafeResultSize($symbol, $args)) {
            if (panicCase($symbol, $args)) {
                fwrite($panic, implode("\t", [$target, ...$args]) . "\n");
            }
            continue;
        }
        yield $args;
    }
    for ($index = 0; $index < RANDOM_CASES; ++$index) {
        $args = array_map(static fn (string $type): string => randomOperand($type, $index), $types);
        if (exactDiv($symbol)) {
            $args[1] = $args[1] === '0' ? '1' : $args[1];
            $args[0] = gmp_strval(gmp_mul($args[0], $args[1]));
        }
        if (unsafeResultSize($symbol, $args)) {
            $args[1] = gmp_strval(gmp_mod($args[1], 257));
        }
        yield $args;
    }
}

function decoded(string $type, string $input): mixed
{
    return match ($type) {
        'DecimalNat', 'DecimalInt' => $input,
        'Bool' => (int) $input,
        'Float' => L\lean_float_of_bits(L\lean_uint64_of_nat(L\lean_cstr_to_nat($input))),
        'Float32' => L\lean_float32_of_bits((int) $input),
        'Nat', 'ValidChar' => L\lean_cstr_to_nat($input),
        'Int' => L\lean_cstr_to_int($input),
        default => match (true) {
            str_starts_with($type, 'Bits'), str_starts_with($type, 'Bounded') => L\lean_cstr_to_nat($input),
            fixedWidth($type) !== 0 => L\numericLowBits(L\lean_cstr_to_int($input), fixedWidth($type)),
            default => throw new LogicException("Unknown PHP input type $type"),
        },
    };
}

function encoded(string $type, mixed $result): string
{
    if ($type === 'Nat' || $type === 'Int') {
        if ($result instanceof GMP && (gmp_cmp($result, PHP_INT_MIN) >= 0 && gmp_cmp($result, PHP_INT_MAX) <= 0)) {
            throw new RuntimeException("Noncanonical GMP result: $result");
        }
        if (!is_int($result) && !($result instanceof GMP)) {
            throw new RuntimeException("Wrong integer result type: " . get_debug_type($result));
        }
        return (string) $result;
    }
    return match ($type) {
        'String' => $result->s,
        'Float' => sprintf('%u', L\lean_float_to_bits($result)),
        'Float32' => (string) L\lean_float32_to_bits($result),
        'FloatPair' => sprintf('%u,%s', L\lean_float_to_bits($result->objs[0]), $result->objs[1]),
        'Float32Pair' => sprintf('%u,%s', L\lean_float32_to_bits($result->objs[0]), $result->objs[1]),
        'Bool', 'Decidable' => ($result === 0 || $result === 1)
            ? (string) $result
            : throw new RuntimeException('Wrong Bool representation.'),
        default => match (true) {
            str_starts_with($type, 'U') => sprintf('%u', $result),
            fixedWidth($type) !== 0 => (string) L\numericSignExtend($result, fixedWidth($type)),
            default => throw new LogicException("Unknown PHP result type $type"),
        },
    };
}

function equalWithinUlp(string $a, string $b, int $width): bool
{
    $a = gmp_init(rtrim($a, "\n"), 10);
    $b = gmp_init(rtrim($b, "\n"), 10);
    $sign = gmp_init(1) << ($width - 1);
    $mask = gmp_sub($sign, 1);
    $aMagnitude = gmp_and($a, $mask);
    $bMagnitude = gmp_and($b, $mask);
    $infinity = gmp_init($width === 32 ? '7f800000' : '7ff0000000000000', 16);
    return gmp_testbit($a, $width - 1) === gmp_testbit($b, $width - 1)
        && gmp_sign($aMagnitude) !== 0 && gmp_sign($bMagnitude) !== 0
        && gmp_cmp($aMagnitude, $infinity) < 0 && gmp_cmp($bMagnitude, $infinity) < 0
        && gmp_cmp(gmp_abs(gmp_sub($a, $b)), 1) <= 0;
}

[, $cases] = cases($dir);
switch ($argv[3]) {
    case 'prepare':
        generateDispatch($dir, $cases);
        $input = fopen("$dir/input", 'w');
        $panic = fopen("$dir/panic-input", 'w');
        foreach ($cases as $key => [$symbol, , $types]) {
            foreach (rows($symbol, $types, $key, $panic) as $args) {
                fwrite($input, implode("\t", [$key, ...$args]) . "\n");
            }
        }
        fclose($input);
        fclose($panic);
        break;
    case 'evaluate':
    case 'compare':
        $compare = $argv[3] === 'compare';
        $oracle = $compare ? fopen("$dir/oracle.out", 'r') : null;
        $matches = 0;
        $withinUlp = 0;
        while (($line = fgets(STDIN)) !== false) {
            $args = explode("\t", rtrim($line, "\n"));
            $key = array_shift($args);
            [$symbol, , $inputs, $output] = $cases[$key];
            $call = RUNTIME . $symbol;
            ob_start();
            try {
                $actual = encoded($output, $call(...array_map(decoded(...), $inputs, $args))) . "\n";
                $unexpected = ob_get_contents();
                if ($unexpected !== '') {
                    throw new RuntimeException('Unexpected runtime output: ' . $unexpected);
                }
            } catch (Throwable $error) {
                throw new RuntimeException("$key (" . implode(', ', $args) . '): ' . $error->getMessage(), previous: $error);
            } finally {
                ob_end_clean();
            }
            if (!$compare) {
                echo $actual;
                continue;
            }
            $expected = fgets($oracle);
            if ($actual === $expected) {
                ++$matches;
                continue;
            }
            $width = match (true) {
                in_array($symbol, FLOAT32_ULP, true) => 32,
                in_array($symbol, FLOAT64_ULP, true) => 64,
                default => 0,
            };
            if ($expected !== false && $width !== 0 && equalWithinUlp($actual, $expected, $width)) {
                ++$withinUlp;
                continue;
            }
            fprintf(STDERR, "%s (%s): Lean %s, PHP %s\n", $key, implode(', ', $args),
                $expected === false ? '<missing>' : rtrim($expected, "\n"), rtrim($actual, "\n"));
            exit(1);
        }
        if ($compare) {
            if (fgets($oracle) !== false) {
                throw new RuntimeException('The oracle returned unexpected trailing output.');
            }
            fclose($oracle);
            printf("numeric output: %d byte-identical, %d within 1 ULP (%d call cases, %d random inputs each)\n",
                $matches, $withinUlp, count($cases), RANDOM_CASES);
        }
        break;
    default:
        throw new LogicException('Unknown numeric test phase.');
}
PHP

php "${php_args[@]}" "$tmp/test.php" "$PWD" "$tmp" prepare
mkdir "$tmp/LeanPhpTest"
cp langs/PHP/LeanPhpTest/{NumericOracle,NumericOracleMain}.lean "$tmp/LeanPhpTest/"
(
  cd "$tmp"
  export LEAN_PATH="$tmp"
  for module in NumericOracle NumericOracleMain; do
    source="LeanPhpTest/$module"
    "$lean" -o "$source.olean" -c "$source.c" "$source.lean"
  done
  "$lean" -c NumericDispatch.c NumericDispatch.lean
  "$leanc" -O2 -o oracle LeanPhpTest/{NumericOracle,NumericOracleMain}.c NumericDispatch.c
)

if ! "$tmp/oracle" < "$tmp/input" > "$tmp/oracle.out"; then
  printf 'Lean numeric oracle failed at '
  sed -n "$(( $(wc -l < "$tmp/oracle.out") + 1 ))p" "$tmp/input"
  exit 1
fi
php "${php_args[@]}" "$tmp/test.php" "$PWD" "$tmp" compare < "$tmp/input"

panic_count=0
while IFS= read -r input; do
  native_status=0
  php_status=0
  "$tmp/oracle" <<< "$input" > "$tmp/native-panic.out" 2> "$tmp/native-panic.err" || native_status=$?
  php "${php_args[@]}" "$tmp/test.php" "$PWD" "$tmp" evaluate <<< "$input" \
    > "$tmp/php-panic.out" 2> "$tmp/php-panic.err" || php_status=$?
  if [[ "$native_status" != 1 || "$php_status" != "$native_status" ]] ||
    ! cmp -s "$tmp/native-panic.out" "$tmp/php-panic.out" ||
    ! cmp -s "$tmp/native-panic.err" "$tmp/php-panic.err"; then
    printf 'Numeric panic mismatch for %s (Lean status %s, PHP status %s)\n' "$input" "$native_status" "$php_status" >&2
    diff -u "$tmp/native-panic.err" "$tmp/php-panic.err" >&2 || true
    exit 1
  fi
  ((++panic_count))
done < "$tmp/panic-input"
printf 'numeric panics: %d byte-identical\n' "$panic_count"
printf 'numeric extern inventory: %s declarations, %s C symbols, 0 missing\n' \
  "$(wc -l < "$tmp/externs.tsv")" "$(cut -f2 "$tmp/externs.tsv" | sort -u | wc -l)"
