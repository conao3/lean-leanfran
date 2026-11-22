<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Conao3\Leanfran\Embed\Files;
use Conao3\Leanfran\Embed\PhpDocType;
use Conao3\Leanfran\Embed\Scanner;
use PhpParser\Node;
use PhpParser\Node\Expr;
use PhpParser\Node\Stmt;
use RuntimeException;

/** Resolves the native value shapes shared by translation and property checks. */
final readonly class Signature
{
    /** Uses the declared types and resolves class names in their source context. */
    public function __construct(
        private string $root,
        private Declaration $model,
        private Objects $objects,
    ) {}

    /** @return array{array<string, Type>, Type} */
    public function read(): array
    {
        $fn = $this->model->node;
        $stmts = $fn->getStmts();
        if ($this->model->error !== null) {
            $this->fail($fn, $this->model->error);
        }
        if ($stmts === null || $fn->byRef || $fn instanceof Stmt\ClassMethod && !$fn->isStatic()) {
            $this->fail($fn, 'expected a static method or named function with a body and by-value return');
        }
        if (!Declaration::dotted($this->model->lean())) {
            $this->fail($fn, 'unsupported function name');
        }
        $doc = $fn->getDocComment()?->getText() ?? '';
        preg_match_all('/@param\s+([^$@\r\n]*?)\$([\w\x80-\xff]+)/', $doc, $matches, PREG_SET_ORDER);
        $paramDocs = [];
        foreach ($matches as [, $type, $name]) {
            $paramDocs[$name] = trim($type);
        }
        $returnDoc = preg_match('/@return\s+([^\r\n*]+)/', $doc, $match) === 1 ? trim($match[1]) : null;
        $result = $this->signatureType($fn, $fn->returnType, $returnDoc);
        $params = [];
        foreach ($fn->params as $param) {
            if ($param->byRef || $param->variadic || !$param->var instanceof Expr\Variable) {
                $this->fail($param, 'reference or variadic parameter');
            }
            $name = self::variable($this->model, $param->var);
            $type = $this->signatureType($param, $param->type, $paramDocs[$name] ?? null);
            $params[$name] = $type;
        }
        return [$params, $result];
    }

    /** Returns the name of a supported local variable. */
    public static function variable(Declaration $model, Expr\Variable $expr): string
    {
        if (
            !is_string($expr->name)
            || !Declaration::dotted($expr->name)
            || in_array(
                $expr->name,
                ['this', 'GLOBALS', '_GET', '_POST', '_FILES', '_COOKIE', '_SESSION', '_REQUEST', '_SERVER', '_ENV'],
                true,
            )
        ) {
            throw new TranslateError($model->where($expr) . ': expected a local variable');
        }
        return $expr->name;
    }

    private function signatureType(Node $where, ?Node $node, ?string $doc): Type
    {
        if ($node instanceof Node\NullableType) {
            $innerDoc = $doc === null ? null : preg_replace('/^\?|\|null\s*$/', '', $doc);
            return new Type('option', [$this->signatureType($where, $node->type, $innerDoc)]);
        }
        if ($node instanceof Node\Name) {
            try {
                return $this->objects->type(
                    $node->toLowerString() === 'self'
                        ? $this->model->class ?? $this->fail($node, 'self outside a class')
                        : $node->toString(),
                );
            } catch (RuntimeException $error) {
                $this->fail($where, $error->getMessage());
            }
        }
        if ($node instanceof Node\Identifier) {
            $name = $node->toLowerString();
            if (in_array($name, ['int', 'bool', 'string', 'float'], true)) {
                return new Type($name);
            }
            if ($name === 'array' && $doc !== null) {
                try {
                    $resolve = Scanner::resolver("$this->root/{$this->model->file}", $this->functionLine());
                    $type = Type::doc(PhpDocType::parse($doc, $resolve, description: true), $this->objects);
                    if ($type->native() === 'array') {
                        return $type;
                    }
                } catch (RuntimeException $error) {
                    $this->fail($where, $error->getMessage());
                }
            }
        }
        $this->fail($where, 'expected a supported native type, with a list or tuple PHPDoc type for array');
    }

    private function functionLine(): int
    {
        $fn = $this->model->node;
        foreach (\PhpToken::tokenize(Files::read("$this->root/{$this->model->file}")) as $token) {
            if ($token->id === T_FUNCTION && $token->pos >= $fn->getStartFilePos()) {
                return $token->line;
            }
        }
        $this->fail($fn, 'missing function token');
    }

    private function fail(Node $node, string $message): never
    {
        throw new TranslateError($this->model->where($node) . ': ' . $message);
    }
}
