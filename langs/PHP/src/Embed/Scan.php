<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Conao3\Leanfran\Lean;
use Conao3\Leanfran\Verify\Discover;
use Conao3\Leanfran\Verify\Lock;
use stdClass;

/** Reads the Lean blocks, models and functions of a Composer project for `leanfran --lang php`. */
final class Scan
{
    /** @return array<string, mixed> */
    public static function run(string $root): array
    {
        self::toolchain($root);
        $project = Project::load($root);
        $blocks = [];
        $embed = '';
        $models = [];
        foreach ($project->blocks as $block) {
            $blocks[] = self::block($project, $block);
            $embed .= "import $block->module\n";
            $models += $project->models[strtolower($block->name)];
        }
        $discovery = Discover::project($project);
        $functions = [];
        foreach ($discovery->models as $key => $model) {
            $functions[] = [
                'id' => $model->name,
                'labels' => $model->labels(),
                'hash' => Lock::digest($project, $discovery, $key),
                'origin' => ['file' => $model->file, 'line' => $model->node->getStartLine(), 'column' => 1],
                'data' => new stdClass(),
            ];
        }
        return [
            'format' => 1,
            'scope' => ['.'],
            'require' => $project->requirements,
            'inputs' => '',
            'blocks' => $blocks,
            'workspace' => [
                ['path' => 'LeanPhpModels.lean', 'text' => implode("\n\n", $models) . "\n"],
                ['path' => 'LeanPhpEmbed.lean', 'text' => $embed],
            ],
            'files' => [],
            'stray' => Status::stray($project),
            'functions' => $functions,
            'proof_inputs' => Lock::inputs($discovery),
        ];
    }

    private static function toolchain(string $root): void
    {
        $file = "$root/lean-toolchain";
        if (!file_exists($file)) {
            return;
        }
        $text = trim(Files::read($file));
        $expected = 'leanprover/lean4:v' . Lean::LEAN_VERSION;
        if ($text !== $expected) {
            throw new EnvironmentError("$file selects $text, but leanfran was built with $expected");
        }
    }

    /** @return array<string, mixed> */
    private static function block(Project $project, Block $block): array
    {
        $imports = $block->imports;
        $open = '';
        $uses = [];
        foreach ($project->dependencies($block) as $dep) {
            $imports[] = $dep->module;
            $open .= "open $dep->module\n";
            $uses[] = $dep->name;
        }
        $models = $project->models[strtolower($block->name)];
        if ($models !== []) {
            $imports[] = 'LeanPhpModels';
            foreach (array_keys($models) as $class) {
                $name = Models::name($class);
                $dot = (int) strrpos($name, '.');
                $open .= 'open ' . substr($name, 0, $dot) . ' (' . substr($name, $dot + 1) . ")\n";
            }
        }
        $types = $project->typeDependencies($block);
        foreach (array_keys($types) as $key) {
            $models += $project->models[$key];
        }
        $prelude = '';
        foreach (array_unique($imports) as $module) {
            $prelude .= "import $module\n";
        }
        return [
            'name' => $block->name,
            'module' => $block->module,
            'path' => str_replace('.', '/', $block->module) . '.lean',
            'prelude' => $prelude . "\nnamespace $block->module\n$open\n",
            'text' => $block->source->text,
            'postlude' => "\n\nend $block->module\n",
            'map' => $block->source->map(),
            'origin' => ['file' => $block->file, 'line' => $block->line, 'column' => $block->column],
            'uses' => $uses,
            'hash' => $project->digest($block),
            'job' => [
                'module' => $block->module,
                'php_namespace' => $block->name,
                'facade' => 'Functions',
                'facade_kind' => 'trait',
                'type_modules' => array_values(array_map(static fn(Block $dep): array => [
                    'namespace' => $dep->module,
                    'php_namespace' => $dep->name,
                ], $types)),
                'models' => array_keys($models),
            ],
            'output' => ['dir' => $block->output],
        ];
    }
}
