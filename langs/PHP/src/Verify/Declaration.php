<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Conao3\Leanfran\Embed\Block;
use Conao3\Leanfran\Embed\Project;
use Conao3\Leanfran\Model;
use PhpParser\Node;
use PhpParser\Node\Stmt;
use PhpParser\PrettyPrinter\Standard;

/** A statically discovered model and the obligations it requests. */
final readonly class Declaration
{
    /** @param array<string, string> $ensures */
    public function __construct(
        public string $name,
        public string $file,
        public string $namespace,
        private string $context,
        public ?string $class,
        public Stmt\Function_|Stmt\ClassMethod $node,
        public ?Block $block,
        public ?string $refines,
        public ?string $requires,
        public array $ensures,
        public ?string $error,
    ) {}

    /** Reads literal arguments from a resolved Model attribute. */
    public static function read(
        Project $project,
        string $file,
        string $namespace,
        string $context,
        ?string $class,
        Stmt\Function_|Stmt\ClassMethod $node,
    ): ?self {
        $attributes = [];
        foreach ($node->attrGroups as $group) {
            foreach ($group->attrs as $attribute) {
                if (strcasecmp($attribute->name->toString(), Model::class) === 0) {
                    $attributes[] = $attribute;
                }
            }
        }
        if ($attributes === []) {
            return null;
        }
        $error = count($attributes) === 1 ? null : 'duplicate Model attribute';
        $options = [];
        $names = ['refines', 'requires', 'ensures', 'spec'];
        $position = 0;
        foreach ($attributes[0]->args as $arg) {
            $key = $arg->name?->toString() ?? $names[$position++] ?? '';
            if (!in_array($key, $names, true) || array_key_exists($key, $options) || $arg->unpack || $arg->byRef) {
                $error = 'invalid Model arguments';
                continue;
            }
            $expr = $arg->value;
            $value = null;
            if ($key === 'ensures' && $expr instanceof Node\Expr\Array_) {
                $value = [];
                foreach ($expr->items as $item) {
                    if (
                        !$item->key instanceof Node\Scalar\String_
                        || !$item->value instanceof Node\Scalar\String_
                        || $item->byRef
                        || $item->unpack
                        || $item->key->value === 'refines'
                        || !self::dotted($item->key->value)
                        || !self::dotted($item->value->value)
                        || array_key_exists($item->key->value, $value)
                    ) {
                        $error = 'ensures must map unique Lean labels to names';
                        continue;
                    }
                    $value[$item->key->value] = $item->value->value;
                }
            } elseif ($key !== 'ensures' && $expr instanceof Node\Scalar\String_) {
                if ($key !== 'spec' && !self::dotted($expr->value)) {
                    $error = "$key must be a Lean name";
                } else {
                    $value = $expr->value;
                }
            } elseif (
                $key === 'spec'
                && $expr instanceof Node\Expr\ClassConstFetch
                && $expr->class instanceof Node\Name
                && $expr->name instanceof Node\Identifier
                && strcasecmp($expr->name->toString(), 'class') === 0
            ) {
                $target = $expr->class->toString();
                $value = strtolower($target) === 'self' ? $class : $target;
            } elseif (
                $key === 'ensures'
                || !$expr instanceof Node\Expr\ConstFetch
                || strtolower($expr->name->toString()) !== 'null'
            ) {
                $error = "invalid literal for Model $key";
            }
            $options[$key] = $value;
        }
        $name = ($class !== null ? "$class\\" : ($namespace === '' ? '' : "$namespace\\")) . $node->name;
        $spec = $options['spec'] ?? $class;
        $block = is_string($spec) ? $project->blocks[strtolower(ltrim($spec, '\\'))] ?? null : null;
        if ($block === null) {
            $error ??= 'Model must select a Lean block using spec';
        }
        $refines = $options['refines'] ?? null;
        $requires = $options['requires'] ?? null;
        $ensures = $options['ensures'] ?? [];
        return new self(
            $name,
            $file,
            $namespace,
            $context,
            $class,
            $node,
            $block,
            is_string($refines) ? $refines : null,
            is_string($requires) ? $requires : null,
            is_array($ensures) ? $ensures : [],
            $error,
        );
    }

    /** Returns the public Lean name. */
    public function lean(): string
    {
        return 'LeanPhpModel.' . str_replace('\\', '.', $this->name);
    }

    /** Returns the source position of a declaration or a node in it. */
    public function where(?Node $node = null): string
    {
        return $this->file . ':' . ($node ?? $this->node)->getStartLine();
    }

    /** @return list<string> */
    public function labels(): array
    {
        $labels = [...($this->refines === null ? [] : ['refines']), ...array_keys($this->ensures)];
        return $labels === [] && $this->error !== null ? ['model'] : $labels;
    }

    /** Hashes the normalized AST, including resolved names and the signature PHPDoc. */
    public function digest(): string
    {
        return hash('sha256', $this->context . "\n" . new Standard()->prettyPrint([$this->node]));
    }

    /** Tests names used for Lean declarations and paths. */
    public static function dotted(string $name): bool
    {
        return preg_match('/^[\p{L}_][\p{L}\p{N}_\x{27}]*(?:\.[\p{L}_][\p{L}\p{N}_\x{27}]*)*$/uD', $name) === 1;
    }
}
