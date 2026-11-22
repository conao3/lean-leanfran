<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Conao3\Leanfran\Lean;
use RuntimeException;
use stdClass;

/** Builds the shared Lake project and generates PHP into staging directories. */
final readonly class Workspace
{
    private const LAKEFILE = <<<'TOML'
        name = "leanfran-php-workspace"
        defaultTargets = ["LeanPhpEmbed", "LeanPhpModels"]

        [[lean_lib]]
        name = "LeanPhpEmbed"

        [[lean_lib]]
        name = "LeanPhpModels"

        [[lean_lib]]
        name = "LeanPhpLib"
        srcDir = "verification"
        globs = ["LeanPhpLib.+"]

        [[lean_lib]]
        name = "LeanPhpModel"
        srcDir = "verification"
        globs = ["LeanPhpModel", "LeanPhpModel.+"]

        [[lean_lib]]
        name = "Proofs"
        srcDir = "verification"
        globs = ["Proofs.+"]
        TOML;

    public string $dir;

    /** Selects the package's workspace. */
    public function __construct(
        private Project $project,
    ) {
        $this->dir = $project->root . '/.leanfran/workspace';
    }

    /** Checks the toolchain and generates all blocks in a single batch. */
    public function generate(string $compiler, string $stage): void
    {
        foreach ([$this->dir, "$this->dir/LeanPhpEmbed"] as $dir) {
            if (is_link($dir)) {
                throw new RuntimeException("workspace path is a symlink: $dir");
            }
            Files::mkdir($dir);
        }
        Files::write("$this->dir/lean-toolchain", $this->project->toolchain . "\n");
        $version = substr($this->project->toolchain, strlen('leanprover/lean4:v'));
        foreach ([
            'lean' => '~^Lean \\(version ([^, )]+)~',
            'lake' => '~\\(Lean version ([^)]+)\\)~',
        ] as $tool => $pattern) {
            $result = Process::run([$tool, '--version'], $this->dir);
            $result->check($tool);
            if (!preg_match($pattern, $result->stdout, $match) || $match[1] !== $version) {
                throw new RuntimeException("$tool must match lean-toolchain ($version): " . trim($result->stdout));
            }
        }
        $result = Process::run([$compiler, '--generator-version'], $this->dir);
        $result->check($compiler);
        $actual = trim($result->stdout);
        if ($actual !== Lean::GENERATOR_VERSION) {
            throw new RuntimeException(
                "$compiler generates version $actual, this package expects " . Lean::GENERATOR_VERSION,
            );
        }
        $this->prepare();
        $heads = [];
        $modules = '';
        $jobs = [];
        foreach ($this->project->blocks as $block) {
            $dependencies = $this->project->dependencies($block);
            $imports = $block->imports;
            $open = '';
            foreach ($dependencies as $dep) {
                $imports[] = $dep->module;
                $open .= "open $dep->module\n";
            }
            $models = $this->project->models[strtolower($block->name)];
            if ($models !== []) {
                $imports[] = 'LeanPhpModels';
                foreach (array_keys($models) as $class) {
                    $name = Models::name($class);
                    $dot = (int) strrpos($name, '.');
                    $open .= 'open ' . substr($name, 0, $dot) . ' (' . substr($name, $dot + 1) . ")\n";
                }
            }
            $types = $this->project->typeDependencies($block);
            foreach ($types as $key => $dep) {
                $models += $this->project->models[$key];
            }
            $header = '';
            foreach (array_unique($imports) as $module) {
                $header .= "import $module\n";
            }
            $header .= "\nnamespace $block->module\n$open\n";
            $path = str_replace('.', '/', $block->module) . '.lean';
            $heads[$path] = [$block, substr_count($header, "\n")];
            Files::write("$this->dir/$path", $header . $block->source->text . "\n\nend $block->module\n");
            $modules .= "import $block->module\n";
            $jobs[] = [
                'module' => $block->module,
                'output_dir' => "$stage/$block->module",
                'php_namespace' => $block->name,
                'facade' => 'Functions',
                'facade_kind' => 'trait',
                'type_modules' => array_values(array_map(static fn(Block $dep): array => [
                    'namespace' => $dep->module,
                    'php_namespace' => $dep->name,
                ], $types)),
                'models' => array_keys($models),
            ];
        }
        foreach (Files::entries("$this->dir/LeanPhpEmbed") as $file) {
            $relative = 'LeanPhpEmbed/' . basename($file);
            if (!isset($heads[$relative]) && preg_match('/^LeanPhpEmbed\/B[0-9a-f]+\.lean$/D', $relative)) {
                Files::remove($file);
            }
        }
        Files::write("$this->dir/LeanPhpEmbed.lean", $modules);
        $build = Process::run(['lake', 'build'], $this->dir);
        $messages = $this->diagnostics($build->stdout . "\n" . $build->stderr, $heads);
        if ($messages !== '') {
            fwrite(STDERR, $messages . "\n");
            if ($build->status !== 0) {
                throw new RuntimeException('lake build failed');
            }
        }
        $build->check('lake build');
        $batch = "$stage/batch.json";
        Files::write($batch, json_encode($jobs, JSON_THROW_ON_ERROR));
        $generate = Process::run(['lake', 'env', $compiler, 'module', 'generate', '--batch', $batch], $this->dir);
        $generate->check('leanfran-php module generate');
    }

    private function prepare(): void
    {
        $lakefile = self::LAKEFILE . "\n";
        foreach ($this->project->requirements as $requirement) {
            $lakefile .= "\n[[require]]\n";
            foreach (get_object_vars($requirement) as $key => $value) {
                if ($key === 'path' && is_string($value) && !str_starts_with($value, '/')) {
                    $value = $this->project->root . '/' . $value;
                }
                $lakefile .= self::toml((string) $key) . ' = ' . self::toml($value) . "\n";
            }
        }
        Files::write("$this->dir/lakefile.toml", $lakefile);
        $models = [];
        foreach ($this->project->models as $definitions) {
            $models += $definitions;
        }
        Files::write("$this->dir/LeanPhpModels.lean", implode("\n\n", $models) . "\n");
        $configured = "$this->dir/lakefile.sha256";
        $hash = hash('sha256', $lakefile) . "\n";
        if (!is_file("$this->dir/lake-manifest.json") || !is_file($configured) || Files::read($configured) !== $hash) {
            Process::run(['lake', 'update'], $this->dir)->check('lake update');
            Files::write($configured, $hash);
        }
    }

    private static function toml(mixed $value): string
    {
        if (is_string($value) || is_int($value) || is_float($value) || is_bool($value)) {
            return json_encode(
                $value,
                JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION,
            );
        }
        if (is_array($value)) {
            return '[' . implode(', ', array_map(self::toml(...), $value)) . ']';
        }
        if ($value instanceof stdClass) {
            $fields = [];
            foreach (get_object_vars($value) as $key => $item) {
                $fields[] = self::toml((string) $key) . ' = ' . self::toml($item);
            }
            return '{ ' . implode(', ', $fields) . ' }';
        }
        throw new RuntimeException('composer.json: unsupported value in extra.leanfran.require');
    }

    /** @param array<string, array{Block, int}> $heads */
    public function diagnostics(string $output, array $heads): string
    {
        $lines = explode("\n", $output);
        $messages = [];
        $continuation = false;
        foreach ($lines as $line) {
            if (preg_match('~^(error|warning): (.*?)(LeanPhpEmbed/[^/:]+\.lean):(\d+):(\d+): (.*)$~', $line, $m)) {
                $info = $heads[$m[3]] ?? null;
                if ($info === null) {
                    $messages[] = $line;
                } else {
                    [$block, $head] = $info;
                    $row = (int) $m[4] - $head;
                    $col = (int) $m[5];
                    $where = $block->location();
                    if ($row > 0) {
                        [$phpRow, $phpCol] = $block->source->position($row, $col);
                        $where = "$block->file:$phpRow:$phpCol";
                    }
                    $messages[] = "$where: $m[1]: (lean block $block->name, Lean $row:$col) $m[6]";
                }
                $continuation = true;
            } elseif (
                trim($line) === ''
                || preg_match('/^(✖|✔|⣿|trace:|info:|error:|warning:|Some required|- )/u', $line)
            ) {
                $continuation = false;
            } elseif ($continuation) {
                $messages[] = $line;
            }
        }
        return implode("\n", $messages);
    }
}
