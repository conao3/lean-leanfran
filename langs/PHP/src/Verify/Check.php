<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Conao3\Leanfran\Embed\Files;
use Conao3\Leanfran\Embed\Process;
use Conao3\Leanfran\Embed\Project;
use RuntimeException;
use stdClass;

/** Builds translated models and classifies each requested proof. */
final class Check
{
    /** @var array<string, Translated> */
    private array $definitions = [];

    /** @var array<string, string> */
    private array $errors = [];

    /** @var array<string, true> */
    private array $active = [];

    private Objects $objects;
    private string $workspace;
    private string $sources;

    /**
     * @param array<string, Declaration> $models
     * @param array<string, true> $functions
     */
    private function __construct(
        private readonly Project $project,
        private readonly array $models,
        private readonly array $functions,
    ) {
        $this->objects = new Objects($project);
        $this->workspace = "$project->root/.leanfran/workspace";
        $this->sources = "$this->workspace/verification";
    }

    /** Checks all models and returns the exit status requested by the caller. */
    public static function run(Project $project, string $compiler, bool $require): int
    {
        $discovery = Discover::project($project);
        $models = $discovery->models;
        if ($models === []) {
            Lock::write($project, [], []);
            return 0;
        }
        $check = new self($project, $models, $discovery->functions);
        $autoload = "$project->root/vendor/autoload.php";
        if (is_file($autoload)) {
            require_once $autoload;
        }
        foreach (array_keys($models) as $key) {
            try {
                $check->translate($key);
            } catch (TranslateError) {
                continue;
            }
        }
        $states = $check->definitions === [] ? [] : $check->judge($compiler);
        $entries = [];
        $exit = 0;
        foreach ($models as $key => $model) {
            $error = $check->errors[$key] ?? null;
            $obligations = [];
            $labels = $model->labels();
            if ($error !== null && $labels === []) {
                $labels = ['model'];
            }
            foreach ($labels as $label) {
                $state = $error === null ? $states[$key][$label] ?? 'missing' : 'unextracted';
                $obligations[$label] = $state;
                $detail = $error === null ? '' : " ($error)";
                fwrite(STDOUT, "$model->name $label: $state$detail\n");
                if ($state === 'unextracted' || $require && $state !== 'proved') {
                    $exit = 1;
                }
            }
            $entries[$key] = [
                'hash' => Lock::digest($project, $discovery, $key),
                'dependencies' => $check->definitions[$key]->dependencies ?? [],
                'obligations' => $obligations,
            ];
        }
        Lock::write($project, $models, $entries);
        return $exit;
    }

    private function translate(string $key): ?Translated
    {
        if (!isset($this->models[$key])) {
            return null;
        }
        if (isset($this->definitions[$key])) {
            return $this->definitions[$key];
        }
        $model = $this->models[$key];
        if (isset($this->errors[$key])) {
            throw new TranslateError($this->errors[$key]);
        }
        if (isset($this->active[$key])) {
            throw new TranslateError($model->where() . ': recursive model calls are outside the subset');
        }
        $this->active[$key] = true;
        try {
            return $this->definitions[$key] = new Translate(
                $this->project->root,
                $model,
                $this->objects,
                $this->translate(...),
                $this->functions,
            )->definition();
        } catch (TranslateError $error) {
            $this->errors[$key] = $error->getMessage();
            throw $error;
        } finally {
            unset($this->active[$key]);
        }
    }

    private function module(string $key): string
    {
        return 'LeanPhpModel.M' . hash('sha256', $key);
    }

    /** @return array<string, array<string, string>> */
    private function judge(string $compiler): array
    {
        $this->prepare();
        $this->writeModule(
            'LeanPhpModel.ValueTypes',
            "import LeanPhpModels\n\n" . implode("\n\n", $this->objects->standalone()) . "\n",
        );
        $groups = [];
        $all = [];
        $specs = ['Lean'];
        $aliases = [];
        foreach ($this->project->blocks as $block) {
            $specs[] = $block->module;
        }
        foreach ($this->definitions as $key => $definition) {
            $model = $definition->model;
            $parts = explode('.', $model->lean());
            array_pop($parts);
            $group = implode('.', $parts);
            $module = $this->module($key);
            $all[] = $module;
            $groups[$group][] = $module;
            $imports = ['LeanPhpLib.Php', 'LeanPhpModel.ValueTypes', 'LeanPhpEmbed'];
            foreach ($definition->dependencies as $child) {
                $imports[] = $this->module($child);
            }
            $this->writeModule($module, self::imports($imports) . "\n" . $definition->source);
            $block = $model->block;
            if ($block !== null) {
                foreach ([$model->refines, $model->requires, ...array_values($model->ensures)] as $spec) {
                    if ($spec !== null) {
                        $aliases[$block->name][$spec] = $block->module;
                    }
                }
            }
        }
        $header = self::imports($specs) . <<<'LEAN'

            open Lean Elab Command in
            elab "leanfran_alias " target:ident " as " alias:ident : command => do
              if (← getEnv).contains target.getId then
                let alias := (← getCurrNamespace) ++ alias.getId
                modifyEnv (Lean.addAlias · alias target.getId)

            LEAN;
        foreach ($aliases as $class => $names) {
            $alias = Translate::leanName('LeanPhpEmbed.' . str_replace('\\', '.', $class));
            $header .= "\nnamespace $alias\n";
            foreach ($names as $name => $module) {
                $spec = Translate::leanName($name);
                $header .= "leanfran_alias $module.$spec as $spec\n";
            }
            $header .= "end $alias\n";
        }
        $this->writeModule('LeanPhpModel.Specs', $header);
        foreach ($groups as $group => $members) {
            if ($group !== 'LeanPhpModel') {
                $this->writeModule($group, self::imports(['LeanPhpModel.Specs', ...$members]));
            }
        }
        $this->writeModule('LeanPhpModel', self::imports(['LeanPhpModel.Specs', ...$all]));
        $proofs = $this->proofs();
        $built = [];
        $full = Process::run(['lake', 'build', '+LeanPhpModel'], $this->workspace);
        if ($full->status === 0) {
            $built[] = 'LeanPhpModel';
        } else {
            foreach ($this->definitions as $key => $definition) {
                $module = $this->module($key);
                $build = Process::run(['lake', 'build', "+$module"], $this->workspace);
                if ($build->status === 0) {
                    $built[] = $module;
                } else {
                    $message = trim($build->stdout . "\n" . $build->stderr);
                    fwrite(STDERR, $definition->model->where() . ": $message\n");
                    $this->errors[$key] =
                        $definition->model->where() . ': could not elaborate the translated definition or spec';
                }
            }
        }
        $failed = [];
        foreach ($proofs as $module => $text) {
            $result = Process::run(['lake', 'build', "+$module"], $this->workspace);
            if ($result->status === 0) {
                $built[] = $module;
            } else {
                fwrite(STDERR, str_replace('verification/Proofs/', 'lean/Proofs/', $result->stdout . $result->stderr));
                $failed[] = $text;
            }
        }
        $refs = [];
        $keys = [];
        foreach ($this->definitions as $key => $definition) {
            if (isset($this->errors[$key])) {
                continue;
            }
            foreach ($definition->model->labels() as $label) {
                $refs[] = ['model' => $definition->model->lean(), 'label' => $label];
                $keys[] = $key;
            }
        }
        if ($refs === []) {
            return [];
        }
        $file = "$this->sources/obligations.json";
        Files::write($file, json_encode($refs, JSON_THROW_ON_ERROR));
        $command = ['lake', 'env', $compiler, 'obligations', 'check', '--modules', ...$built, '--obligations', $file];
        $result = Process::run($command, $this->workspace);
        $result->check('leanfran-php obligations check');
        $decoded = json_decode($result->stdout, flags: JSON_THROW_ON_ERROR);
        if (!is_array($decoded) || count($decoded) !== count($refs)) {
            throw new RuntimeException('unexpected obligations check response');
        }
        $states = [];
        foreach ($refs as $index => $ref) {
            $row = $decoded[$index] ?? null;
            if (
                !$row instanceof stdClass
                || !is_string($row->status ?? null)
                || ($row->model ?? null) !== $ref['model']
                || ($row->label ?? null) !== $ref['label']
            ) {
                throw new RuntimeException('invalid obligation in compiler response');
            }
            $state = $row->status;
            if ($state === 'missing' && self::failed($failed, $ref['model'], $ref['label'])) {
                $state = 'failed';
            }
            if ($state === 'mismatch' && is_string($row->detail ?? null)) {
                fwrite(STDERR, $row->detail . "\n");
            }
            if ($state === 'axioms' && is_array($row->axioms ?? null)) {
                $axioms = array_filter($row->axioms, is_string(...));
                fwrite(STDERR, $ref['model'] . '.proof.' . $ref['label'] . ' uses ' . implode(', ', $axioms) . "\n");
            }
            $states[$keys[$index]][$ref['label']] = $state;
        }
        return $states;
    }

    private function prepare(): void
    {
        if (is_link($this->sources)) {
            throw new RuntimeException("unexpected symlink at $this->sources");
        }
        if (is_dir($this->sources)) {
            Files::remove($this->sources);
        }
        Files::mkdir($this->sources);
        $this->writeModule('LeanPhpLib.Php', Lock::library());
    }

    /** @return array<string, string> */
    private function proofs(): array
    {
        $parent = "{$this->project->root}/lean/Proofs";
        if (!is_dir($parent)) {
            return [];
        }
        $out = [];
        foreach (Files::walk($parent) as $path) {
            if (!str_ends_with($path, '.lean')) {
                continue;
            }
            $name = 'Proofs.' . str_replace('/', '.', substr($path, strlen($parent) + 1, -5));
            if (!Declaration::dotted($name)) {
                throw new RuntimeException("$path: invalid proof module name");
            }
            $out[$name] = Files::read($path);
            $this->writeModule($name, $out[$name]);
        }
        return $out;
    }

    private function writeModule(string $name, string $text): void
    {
        $path = $this->sources . '/' . str_replace('.', '/', $name) . '.lean';
        Files::mkdir(dirname($path));
        Files::write($path, $text);
    }

    /** @param list<string> $modules */
    private static function imports(array $modules): string
    {
        return implode('', array_map(
            static fn(string $name): string => 'import ' . Translate::leanName($name) . "\n",
            $modules,
        ));
    }

    /** @param list<string> $sources */
    private static function failed(array $sources, string $model, string $label): bool
    {
        $parts = explode('.', $model);
        $theorem = (string) end($parts) . '.proof.' . $label;
        $pattern = '/\b(?:theorem|lemma|def|example)\s+[^\s:]*\b' . preg_quote($theorem, '/') . '(?![\w.])/u';
        foreach ($sources as $source) {
            if (preg_match($pattern, str_replace(['«', '»'], '', $source)) === 1) {
                return true;
            }
        }
        return false;
    }
}
