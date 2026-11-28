<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Conao3\Leanfran\Embed\Project;

/** Translates the #[Model] functions to the Lean modules that `leanfran --lang php check` builds. */
final class Check
{
    /** @var array<string, Translated> */
    private array $definitions = [];

    /** @var array<string, string> */
    private array $errors = [];

    /** @var array<string, true> */
    private array $active = [];

    private Objects $objects;

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
    }

    /**
     * Returns the modules, aggregates and functions of `translate`.
     *
     * @return array<string, mixed>
     */
    public static function run(string $root): array
    {
        $project = Project::load($root);
        $discovery = Discover::project($project);
        $check = new self($project, $discovery->models, $discovery->functions);
        foreach (array_keys($discovery->models) as $key) {
            try {
                $check->translate($key);
            } catch (TranslateError) {
                continue;
            }
        }
        [$modules, $aggregates] = $check->definitions === [] ? [[], []] : $check->modules();
        $functions = [];
        foreach ($discovery->models as $key => $model) {
            $error = $check->errors[$key] ?? null;
            $function = ['id' => $model->name, 'model' => $model->lean()];
            if ($error === null) {
                $function['dependencies'] = array_map(
                    fn(string $child): string => $discovery->models[$child]->name,
                    $check->definitions[$key]->dependencies ?? [],
                );
            } else {
                $function['error'] = self::error($model, $error);
            }
            $functions[] = $function;
        }
        return ['format' => 1, 'modules' => $modules, 'aggregates' => $aggregates, 'functions' => $functions];
    }

    /** @return array{file: string, line: int, column: int, message: string} */
    private static function error(Declaration $model, string $message): array
    {
        $prefix = $model->file . ':';
        if (str_starts_with($message, $prefix) && preg_match('/^(\d+): (.*)$/sD', substr($message, strlen($prefix)), $m)) {
            return ['file' => $model->file, 'line' => (int) $m[1], 'column' => 1, 'message' => $m[2]];
        }
        return ['file' => $model->file, 'line' => $model->node->getStartLine(), 'column' => 1, 'message' => $message];
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

    /** @return array{list<array<string, mixed>>, list<array<string, string>>} */
    private function modules(): array
    {
        $groups = [];
        $all = [];
        $specs = ['Lean'];
        $aliases = [];
        $translated = [];
        foreach ($this->project->blocks as $block) {
            $specs[] = $block->module;
        }
        foreach ($this->ordered() as $key) {
            $definition = $this->definitions[$key];
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
            $translated[] = self::file($module, self::imports($imports) . "\n" . $definition->source) + [
                'functions' => [$model->name],
            ];
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
        $modules = [
            self::file(
                'LeanPhpModel.ValueTypes',
                "import LeanPhpModels\n\n" . implode("\n\n", $this->objects->standalone()) . "\n",
            ) + ['functions' => []],
            self::file('LeanPhpModel.Specs', $header) + ['functions' => []],
            ...$translated,
        ];
        $aggregates = [];
        foreach ($groups as $group => $members) {
            if ($group !== 'LeanPhpModel') {
                $aggregates[] = self::file($group, self::imports(['LeanPhpModel.Specs', ...$members]));
            }
        }
        $aggregates[] = self::file('LeanPhpModel', self::imports(['LeanPhpModel.Specs', ...$all]));
        return [$modules, $aggregates];
    }

    /**
     * Orders the translated models so that each model follows the models it calls.
     *
     * @return list<string>
     */
    private function ordered(): array
    {
        $order = [];
        $visit = function (string $key) use (&$visit, &$order): void {
            if (isset($order[$key]) || !isset($this->definitions[$key])) {
                return;
            }
            $order[$key] = false;
            foreach ($this->definitions[$key]->dependencies as $child) {
                $visit($child);
            }
            unset($order[$key]);
            $order[$key] = true;
        };
        foreach (array_keys($this->definitions) as $key) {
            $visit($key);
        }
        return array_keys($order);
    }

    /** @return array{module: string, path: string, text: string} */
    private static function file(string $name, string $text): array
    {
        return ['module' => Translate::leanName($name), 'path' => 'verification/' . str_replace('.', '/', $name) . '.lean', 'text' => $text];
    }

    /** @param list<string> $modules */
    private static function imports(array $modules): string
    {
        return implode('', array_map(
            static fn(string $name): string => 'import ' . Translate::leanName($name) . "\n",
            $modules,
        ));
    }
}
