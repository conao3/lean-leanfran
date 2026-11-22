<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

use Closure;
use Conao3\Leanfran\Lean;
use Generator;
use ParseError;
use PhpToken;
use RuntimeException;

/** Finds Lean attributes without loading the PHP file. */
final class Scanner
{
    private const NAME = [T_STRING, T_NAME_QUALIFIED, T_NAME_FULLY_QUALIFIED, T_NAME_RELATIVE];

    private const IMPORT_NAME = <<<'REGEX'
        ~^(?<part>[\p{L}_\x{2100}-\x{214f}][\p{L}\p{N}_'!?\x{2090}-\x{209c}\x{2100}-\x{214f}]*|«[^»\x00-\x1f]+»)(?:\.(?&part))*$~uD
        REGEX;

    private string $namespace = '';

    /** @param array<string, string> $aliases */
    private function __construct(
        private readonly string $file,
        private readonly string $input,
        private array $aliases = [],
    ) {}

    /**
     * Reads all Lean blocks in a PHP file.
     *
     * @return list<Block>
     */
    public static function scan(string $file, string $input): array
    {
        $scanner = new self($file, str_replace(["\r\n", "\r"], "\n", $input));
        $blocks = [];
        foreach ($scanner->declarations() as [$name, $attributes]) {
            if (isset($attributes[1])) {
                $scanner->fail($attributes[1]->peek(), 'duplicate Lean attribute on the same class');
            }
            if (isset($attributes[0])) {
                $blocks[] = $scanner->block($name, $attributes[0]);
            }
        }
        return $blocks;
    }

    /** @return Closure(string): string */
    public static function resolver(string $file, string $class): Closure
    {
        $scanner = new self($file, str_replace(["\r\n", "\r"], "\n", Files::read($file)));
        foreach ($scanner->declarations() as [$name]) {
            if ($scanner->qualify($name) === $class) {
                return $scanner->resolve(...);
            }
        }
        throw new RuntimeException("$file: cannot find model declaration for $class");
    }

    /** @return Generator<int, array{string, list<Tokens>}> */
    private function declarations(): Generator
    {
        try {
            $tokens = array_values(array_filter(
                PhpToken::tokenize($this->input, TOKEN_PARSE),
                static fn(PhpToken $token): bool => !$token->isIgnorable(),
            ));
        } catch (ParseError $error) {
            throw new RuntimeException("$this->file:{$error->getLine()}: {$error->getMessage()}", previous: $error);
        }
        $tokens = new Tokens($tokens, new PhpToken(0, '', substr_count($this->input, "\n") + 1, strlen($this->input)));
        $attributes = [];
        $depth = 0;
        $namespaceDepth = 0;
        while (!$tokens->peek()->is(0)) {
            $token = $tokens->take();
            if ($token->is(T_ATTRIBUTE)) {
                foreach ($tokens->items(']') as $attribute) {
                    if (strcasecmp($this->resolve($attribute->peek()->text), Lean::class) === 0) {
                        $attributes[] = $attribute;
                    }
                }
                continue;
            }
            if ($token->is([T_FINAL, T_ABSTRACT, T_READONLY])) {
                continue;
            }
            if ($token->is([T_CLASS, T_TRAIT, T_ENUM]) && $tokens->peek()->is(T_STRING)) {
                yield [$tokens->take()->text, $token->is(T_CLASS) ? $attributes : []];
            }
            $attributes = [];
            if ($token->is(T_NAMESPACE)) {
                $this->namespace = $tokens->peek()->is(self::NAME) ? $tokens->take()->text : '';
                $this->aliases = [];
                $namespaceDepth = $tokens->peek()->is('{') ? 1 : 0;
            } elseif ($token->is(T_USE) && $depth === $namespaceDepth && !$tokens->peek()->is('(')) {
                $this->readUse($tokens);
            } elseif ($token->is([ord('{'), T_CURLY_OPEN, T_DOLLAR_OPEN_CURLY_BRACES])) {
                $depth++;
            } elseif ($token->is(ord('}'))) {
                if ($depth === 1 && $namespaceDepth === 1) {
                    $this->namespace = '';
                    $this->aliases = [];
                    $namespaceDepth = 0;
                }
                $depth--;
            }
        }
    }

    private function readUse(Tokens $tokens): void
    {
        foreach ($tokens->items(';') as $item) {
            if ($item->peek()->is([T_FUNCTION, T_CONST])) {
                continue;
            }
            $name = $item->take()->text;
            if ($item->skip(T_NS_SEPARATOR)) {
                $item->take();
                foreach ($item->items('}') as $part) {
                    if (!$part->peek()->is([T_FUNCTION, T_CONST])) {
                        $this->addAlias($name . '\\' . $part->take()->text, $part);
                    }
                }
            } else {
                $this->addAlias($name, $item);
            }
        }
    }

    private function addAlias(string $name, Tokens $tokens): void
    {
        $parts = explode('\\', $name);
        $alias = $tokens->skip(T_AS) ? $tokens->take()->text : end($parts);
        $this->aliases[strtolower($alias)] = ltrim($name, '\\');
    }

    private function resolve(string $name): string
    {
        if (str_starts_with($name, '\\')) {
            return substr($name, 1);
        }
        $parts = explode('\\', $name, 2);
        $first = strtolower($parts[0]);
        if ($first === 'namespace' && isset($parts[1])) {
            return $this->qualify($parts[1]);
        }
        if (isset($this->aliases[$first])) {
            return $this->aliases[$first] . (isset($parts[1]) ? '\\' . $parts[1] : '');
        }
        return $this->qualify($name);
    }

    private function qualify(string $name): string
    {
        return $this->namespace === '' ? $name : $this->namespace . '\\' . $name;
    }

    private function block(string $class, Tokens $attribute): Block
    {
        $name = $attribute->take();
        $fields = ['source', 'imports', 'uses', 'models'];
        $values = [];
        $named = false;
        if ($attribute->skip('(')) {
            foreach ($attribute->items(')') as $i => $argument) {
                $at = $argument->peek();
                if ($argument->peek(1)->is(':')) {
                    $key = $argument->take()->text;
                    $argument->take();
                    $named = true;
                } else {
                    $key = $named ? null : $fields[$i] ?? null;
                }
                if ($key === null || !in_array($key, $fields, true) || isset($values[$key])) {
                    $this->fail($at, 'invalid or duplicate Lean attribute argument');
                }
                $values[$key] = $argument;
            }
        }
        $source = isset($values['source'])
            ? $this->source($values['source'])
            : $this->fail($name, 'missing Lean source');
        $imports = isset($values['imports']) ? $this->names($values['imports'], true) : [];
        $uses = isset($values['uses']) ? $this->names($values['uses'], false) : [];
        $models = isset($values['models']) ? $this->names($values['models'], false) : [];
        return new Block(
            $this->qualify($class),
            $this->file,
            $name->line,
            $this->column($name),
            $source,
            $imports,
            $uses,
            $models,
        );
    }

    private function source(Tokens $tokens): Source
    {
        $start = $tokens->take();
        if ($start->is(T_CONSTANT_ENCAPSED_STRING) && str_starts_with($start->text, "'") && $tokens->peek()->is(0)) {
            return new Source(
                explode("\n", substr($start->text, 1, -1)),
                $start->line,
                $this->column($start) + 1,
                '',
                true,
            );
        }
        if ($start->is(T_START_HEREDOC) && preg_match("~^<<<[ \t]*'~", $start->text)) {
            $body = $tokens->peek()->is(T_ENCAPSED_AND_WHITESPACE) ? $tokens->take()->text : '';
            $end = $tokens->peek();
            if ($tokens->skip(T_END_HEREDOC) && $tokens->peek()->is(0)) {
                $indent = substr($end->text, 0, strspn($end->text, " \t"));
                $lines = explode("\n", str_ends_with($body, "\n") ? substr($body, 0, -1) : $body);
                return new Source($lines, $start->line + 1, strlen($indent) + 1, $indent, false);
            }
        }
        $this->fail($start, 'Lean source must be a nowdoc or a single-quoted literal');
    }

    /** @return list<string> */
    public function names(Tokens $tokens, bool $imports): array
    {
        $at = $tokens->peek();
        if ($tokens->skip('[')) {
            $items = $tokens->items(']');
        } elseif ($tokens->skip(T_ARRAY) && $tokens->skip('(')) {
            $items = $tokens->items(')');
        } else {
            $this->fail($at, 'Lean attribute argument must be a literal array');
        }
        if (!$tokens->peek()->is(0)) {
            $this->fail($tokens->peek(), 'Lean attribute argument must be a literal array');
        }
        $names = [];
        foreach ($items as $item) {
            $token = $item->take();
            if ($token->is(T_CONSTANT_ENCAPSED_STRING)) {
                $name = $this->literal($token);
            } elseif (
                $token->is(self::NAME)
                && $item->skip(T_DOUBLE_COLON)
                && $item->peek()->is(T_STRING)
                && strcasecmp($item->take()->text, 'class') === 0
            ) {
                $name = $this->resolve($token->text);
                if ($imports) {
                    $name = str_replace('\\', '.', $name);
                }
            } else {
                $this->fail($token, 'expected a string or X::class literal');
            }
            if (!$item->peek()->is(0)) {
                $this->fail($item->peek(), 'expected a string or X::class literal');
            }
            if ($imports && !preg_match(self::IMPORT_NAME, $name)) {
                $this->fail($token, "invalid Lean import '$name'");
            }
            $names[] = $imports ? $name : ltrim($name, '\\');
        }
        return $names;
    }

    private function literal(PhpToken $token): string
    {
        $text = substr($token->text, 1, -1);
        if (str_starts_with($token->text, "'")) {
            return Source::singleQuoted($text);
        }
        $escapes = <<<'REGEX'
            ~\\(?:[0-7]{1,3}|x[0-9a-fA-F]{1,2}|u\{[0-9a-fA-F]+\}|[nrtvef\\$"])~
            REGEX;
        return (
            preg_replace_callback(
                $escapes,
                static function (array $match): string {
                    if (str_starts_with($match[0], '\\u{')) {
                        $point = (int) hexdec(substr($match[0], 3, -1));
                        return html_entity_decode("&#$point;", ENT_QUOTES, 'UTF-8');
                    }
                    return $match[0] === '\\$' ? '$' : stripcslashes($match[0]);
                },
                $text,
            ) ?? $this->fail($token, 'invalid PHP string literal')
        );
    }

    private function column(PhpToken $token): int
    {
        $prefix = substr($this->input, 0, $token->pos);
        $newline = strrpos($prefix, "\n");
        return Source::length($newline === false ? $prefix : substr($prefix, $newline + 1)) + 1;
    }

    private function fail(PhpToken $at, string $message): never
    {
        throw new RuntimeException("$this->file:{$at->line}:{$this->column($at)}: $message");
    }
}
