<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Composer\Autoload\ClassLoader;
use Conao3\Leanfran\Embed\Files;
use Conao3\Leanfran\Embed\Project;
use Conao3\Leanfran\Embed\Scanner;
use PhpParser\Node;
use PhpParser\NodeFinder;
use PhpParser\NodeTraverser;
use PhpParser\NodeVisitor\NameResolver;
use PhpParser\ParserFactory;
use PhpParser\PrettyPrinter\Standard;
use RuntimeException;

/** Finds PHP functions marked with Model without invoking their source. */
final readonly class Discover
{
    /**
     * @param array<string, Declaration> $models
     * @param array<string, true> $functions
     */
    private function __construct(
        public array $models,
        public array $functions,
    ) {}

    /** Reads model declarations and function names needed to resolve PHP's global fallback. */
    public static function project(Project $project): self
    {
        $models = [];
        $scanned = [];
        foreach ($project->sources as $file) {
            $source = Files::read("$project->root/$file");
            $line = Scanner::modelLine($file, $source);
            if ($line === null) {
                continue;
            }
            $vendor = "$project->root/vendor";
            if (is_file("$vendor/autoload.php")) {
                require_once "$vendor/autoload.php";
            }
            $loader = ClassLoader::getRegisteredLoaders()[$vendor] ?? null;
            if (
                $loader === null
                || $loader->findFile(ParserFactory::class) === false
                || !class_exists(ParserFactory::class)
            ) {
                throw new RuntimeException(
                    "$file:$line: install the PHP model parser with composer require --dev nikic/php-parser:^5.9",
                );
            }
            $nodes = $scanned[$file] = self::parse($file, $source);
            foreach (self::declarations($project, $file, '', $nodes) as $model) {
                $key = strtolower($model->name);
                if (isset($models[$key])) {
                    throw new RuntimeException($model->where() . ": duplicate model $model->name");
                }
                $models[$key] = $model;
            }
        }
        $functions = [];
        if ($models !== []) {
            $finder = new NodeFinder();
            foreach ($project->sources as $file) {
                $nodes = $scanned[$file] ?? self::parse($file, Files::read("$project->root/$file"));
                foreach ($finder->findInstanceOf($nodes, Node\Stmt\Function_::class) as $function) {
                    $name = $function->namespacedName ?? null;
                    if ($name !== null) {
                        $functions[strtolower($name->toString())] = true;
                    }
                }
            }
        }
        return new self($models, $functions);
    }

    /** @return array<Node> */
    private static function parse(string $file, string $source): array
    {
        try {
            $nodes = new ParserFactory()
                ->createForHostVersion()
                ->parse($source) ?? [];
            return new NodeTraverser(new NameResolver())->traverse($nodes);
        } catch (\PhpParser\Error $error) {
            throw new RuntimeException("$file:{$error->getStartLine()}: {$error->getRawMessage()}", previous: $error);
        }
    }

    /**
     * @param array<Node> $nodes
     * @return iterable<Declaration>
     */
    private static function declarations(Project $project, string $file, string $namespace, array $nodes): iterable
    {
        $imports = array_values(array_filter(
            $nodes,
            static fn(Node $node): bool => $node instanceof Node\Stmt\Use_ || $node instanceof Node\Stmt\GroupUse,
        ));
        $context = new Standard()->prettyPrint($imports);
        foreach ($nodes as $node) {
            if ($node instanceof Node\Stmt\Namespace_) {
                yield from self::declarations($project, $file, $node->name?->toString() ?? '', $node->stmts);
            } elseif ($node instanceof Node\Stmt\Function_) {
                $model = Declaration::read($project, $file, $namespace, $context, null, $node);
                if ($model !== null) {
                    yield $model;
                }
            } elseif ($node instanceof Node\Stmt\ClassLike && $node->namespacedName !== null) {
                foreach ($node->getMethods() as $method) {
                    $model = Declaration::read(
                        $project,
                        $file,
                        $namespace,
                        $context,
                        $node->namespacedName->toString(),
                        $method,
                    );
                    if ($model !== null) {
                        yield $model;
                    }
                }
            }
        }
    }
}
