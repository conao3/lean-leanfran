#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ || -z $2 ]]; then
    echo "Usage: $0 <vX.Y.Z> <output-directory>" >&2
    exit 2
fi

tag=$1
output=$(realpath -m -- "$2")
cd "$(dirname "$0")/../.."
mkdir -p -- "$(dirname "$output")"
snapshot=$(mktemp -d "$(dirname "$output")/.leanfran-php.XXXXXXXX")
trap 'rm -rf -- "$snapshot"' EXIT

cp -R -- langs/PHP/composer.json langs/PHP/src langs/PHP/bin LICENSE "$snapshot/"
cat > "$snapshot/README.md" <<'EOF'
This repository is a read-only mirror of [`langs/PHP/`](https://github.com/conao3/lean-leanfran/tree/master/langs/PHP) in `conao3/lean-leanfran`.
Please open issues and pull requests in the [source repository](https://github.com/conao3/lean-leanfran).

EOF
cat langs/PHP/README.md >> "$snapshot/README.md"

(
    cd "$snapshot"
    php <<'PHP'
<?php
$manifest = json_decode(file_get_contents('composer.json'), true, 512, JSON_THROW_ON_ERROR);
if (($manifest['name'] ?? null) !== 'conao3/leanfran' || array_key_exists('version', $manifest)) {
    fwrite(STDERR, "composer.json must name conao3/leanfran and derive its version from the Git tag.\n");
    exit(1);
}

$autoload = $manifest['autoload'] ?? [];
$namespaces = $autoload['psr-4'] ?? [];
$files = $autoload['files'] ?? [];
if (empty($namespaces['Conao3\\Leanfran\\']) || empty($files)) {
    fwrite(STDERR, "composer.json must declare the Conao3\\Leanfran\\ PSR-4 namespace and runtime files.\n");
    exit(1);
}

$checkPath = static function (string $path, callable $exists): void {
    $resolved = realpath($path);
    if (!str_starts_with($path, 'src/') || $resolved === false
        || !str_starts_with($resolved . '/', getcwd() . '/src/') || !$exists($resolved)) {
        fwrite(STDERR, "Composer autoload path must resolve within src/: {$path}\n");
        exit(1);
    }
};
foreach ($namespaces as $paths) {
    foreach ((array) $paths as $path) {
        $checkPath($path, is_dir(...));
    }
}
foreach ($files as $path) {
    $checkPath($path, is_file(...));
}
PHP
    COMPOSER_DISABLE_NETWORK=1 COMPOSER_ROOT_VERSION="${tag#v}" composer validate --strict
)

mv -T -- "$snapshot" "$output"
printf 'Prepared PHP mirror snapshot for %s\n' "$tag"
