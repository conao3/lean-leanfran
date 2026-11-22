<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Verify;

use Closure;
use Conao3\Leanfran\Embed\PhpDocType;
use Conao3\Leanfran\Embed\Scanner;
use PhpParser\Node;
use PhpParser\Node\Expr;
use PhpParser\Node\Stmt;
use PhpParser\NodeFinder;
use RuntimeException;

/** Lowers the typed PHP subset to Lean do notation. */
final class Translate
{
    public const BUILTINS = ['intdiv' => 2, 'min' => 2, 'max' => 2, 'abs' => 1, 'strlen' => 1, 'count' => 1];

    /** @var array<string, Type> */
    private array $locals = [];

    /** @var array<string, true> */
    private array $lists = [];

    /** @var list<array<Expr>> */
    private array $loops = [];

    /** @var array<string, true> */
    private array $dependencies = [];

    private bool $fails = false;
    private int $next = 0;
    private Type $result;

    /**
     * @param Closure(string): (Translated|null) $target
     * @param array<string, true> $functions
     */
    public function __construct(
        private readonly string $root,
        private readonly Declaration $model,
        private readonly Objects $objects,
        private readonly Closure $target,
        private readonly array $functions,
    ) {}

    /** Quotes a Lean identifier while preserving its declaration name. */
    public static function ident(string $id): string
    {
        return "«{$id}»";
    }

    /** Quotes a dot-separated Lean declaration name. */
    public static function leanName(string $name): string
    {
        return implode('.', array_map(self::ident(...), explode('.', $name)));
    }

    /** Translates a function and appends the propositions requested by its attribute. */
    public function definition(): Translated
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
        $this->result = $this->signatureType($fn, $fn->returnType, $returnDoc);
        $params = [];
        $binders = [];
        $args = [];
        foreach ($fn->params as $param) {
            if ($param->byRef || $param->variadic || !$param->var instanceof Expr\Variable) {
                $this->fail($param, 'reference or variadic parameter');
            }
            $name = $this->variable($param->var);
            $type = $this->signatureType($param, $param->type, $paramDocs[$name] ?? null);
            $params[$name] = $type;
            $args[] = self::ident($name);
            $binders[] = '(' . self::ident($name) . ' : ' . $type->lean() . ')';
        }
        $this->locals = $params;
        if (!$this->returns($stmts)) {
            $this->fail($fn, 'a function must return a value or throw on every path');
        }
        $body = $this->statements($stmts, '  ');
        $name = self::leanName($this->model->lean());
        $return = $this->result->lean();
        $binder = $binders === [] ? '' : ' ' . implode(' ', $binders);
        $entry = $this->fails ? 'do' : 'Id.run do';
        $output = $this->fails ? "(Php.M $return)" : $return;
        $source = "def $name$binder : $output := $entry\n";
        foreach ($args as $arg) {
            $source .= "  let mut $arg := $arg\n";
        }
        $source .= $body;
        $block = $this->model->block ?? $this->fail($fn, 'missing spec block');
        $argsCode = $args === [] ? '' : ' ' . implode(' ', $args);
        $call = "($name$argsCode)";
        $forall = $binder === '' ? '' : "∀$binder, ";
        $requires = $this->model->requires;
        $pre = $requires === null ? '' : "_root_.$block->module." . self::leanName($requires) . "$argsCode = true → ";
        if ($this->model->refines !== null) {
            $spec = "(_root_.$block->module." . self::leanName($this->model->refines) . "$argsCode)";
            $rhs = $this->fails ? "Except.ok $spec" : $spec;
            $source .= "\nabbrev $name.obligation.refines : Prop :=\n  $forall$pre$call = $rhs\n";
        }
        foreach ($this->model->ensures as $label => $spec) {
            $label = self::leanName($label);
            $spec = "_root_.$block->module." . self::leanName($spec) . $argsCode;
            $predicate = $this->fails
                ? "∀ «%result», $call = .ok «%result» → $spec «%result» = true"
                : "$spec $call = true";
            $source .= "\nabbrev $name.obligation.$label : Prop :=\n  $forall$pre$predicate\n";
        }
        return new Translated(
            $this->model,
            $params,
            $this->result,
            $this->fails,
            $source,
            array_keys($this->dependencies),
        );
    }

    private function signatureType(Node $where, ?Node $node, ?string $doc): Type
    {
        if ($node instanceof Node\NullableType) {
            $innerDoc = $doc === null ? null : preg_replace('/^\?|\|null\s*$/', '', $doc);
            return new Type('option', [$this->signatureType($where, $node->type, $innerDoc)]);
        }
        if ($node instanceof Node\Name) {
            try {
                return $this->objects->type($this->className($node));
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
        foreach (\PhpToken::tokenize(\Conao3\Leanfran\Embed\Files::read(
            "$this->root/{$this->model->file}",
        )) as $token) {
            if ($token->id === T_FUNCTION && $token->pos >= $fn->getStartFilePos()) {
                return $token->line;
            }
        }
        $this->fail($fn, 'missing function token');
    }

    private function className(Node\Name $name): string
    {
        return strtolower($name->toString()) === 'self'
            ? $this->model->class ?? $this->fail($name, 'self outside a class')
            : $name->toString();
    }

    private function variable(Expr\Variable $expr): string
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
            $this->fail($expr, 'expected a local variable');
        }
        return $expr->name;
    }

    private function fail(Node $node, string $message): never
    {
        throw new TranslateError($this->model->where($node) . ': ' . $message);
    }

    /** @param array<Stmt> $stmts */
    private function returns(array $stmts): bool
    {
        foreach ($stmts as $stmt) {
            if (
                $stmt instanceof Stmt\Return_
                || $stmt instanceof Stmt\Expression && $stmt->expr instanceof Expr\Throw_
            ) {
                return true;
            }
            if (
                $stmt instanceof Stmt\If_
                && $stmt->else !== null
                && $this->returns($stmt->stmts)
                && $this->returns($stmt->else->stmts)
                && array_all($stmt->elseifs, fn(Stmt\ElseIf_ $else): bool => $this->returns($else->stmts))
            ) {
                return true;
            }
        }
        return false;
    }

    /** @param array<Stmt> $stmts */
    private function statements(array $stmts, string $pad): string
    {
        $out = '';
        $stmts = array_values($stmts);
        foreach ($stmts as $index => $stmt) {
            if ($stmt instanceof Stmt\If_) {
                $tail = array_slice($stmts, $index + 1);
                if ($tail !== [] && $this->usesBranchLocal($stmt, $tail)) {
                    return $out . $this->conditional($stmt, $pad, $tail);
                }
            }
            $out .= $this->statement($stmt, $pad);
        }
        return $out === '' ? "{$pad}pure ()\n" : $out;
    }

    /** @param array<Stmt> $stmts */
    private function nested(array $stmts, string $pad): string
    {
        $locals = $this->locals;
        $lists = $this->lists;
        $body = $this->statements($stmts, $pad);
        $this->locals = $locals;
        $this->lists = array_intersect_key($lists, $this->lists);
        return $body;
    }

    private function statement(Stmt $stmt, string $pad): string
    {
        if ($stmt instanceof Stmt\Return_ && $stmt->expr !== null) {
            $value = $this->expect($stmt->expr, $this->result);
            return "{$pad}return $value->code\n";
        }
        if ($stmt instanceof Stmt\Expression) {
            return $this->expressionStatement($stmt->expr, $pad);
        }
        if ($stmt instanceof Stmt\If_) {
            return $this->conditional($stmt, $pad);
        }
        if ($stmt instanceof Stmt\While_ || $stmt instanceof Stmt\For_) {
            return $this->loop($stmt, $pad);
        }
        if ($stmt instanceof Stmt\Foreach_) {
            return $this->foreach($stmt, $pad);
        }
        if ($stmt instanceof Stmt\Break_ || $stmt instanceof Stmt\Continue_) {
            if (
                $this->loops === []
                || $stmt->num !== null && (!$stmt->num instanceof Node\Scalar\Int_ || $stmt->num->value !== 1)
            ) {
                $this->fail($stmt, 'expected a single-level break or continue in a loop');
            }
            return $stmt instanceof Stmt\Break_
                ? "{$pad}break\n"
                : $this->updates($this->loops[array_key_last($this->loops)], $pad) . "{$pad}continue\n";
        }
        if ($stmt instanceof Stmt\Nop) {
            return '';
        }
        $this->fail($stmt, 'unsupported statement ' . $stmt->getType());
    }

    /** @param list<Stmt> $tail */
    private function usesBranchLocal(Stmt\If_ $stmt, array $tail): bool
    {
        $finder = new NodeFinder();
        $names = [];
        foreach ($finder->findInstanceOf($stmt, Expr\Assign::class) as $assignment) {
            $destinations = $assignment->var instanceof Expr\Variable
                ? [$assignment->var]
                : (
                    $assignment->var instanceof Expr\List_ || $assignment->var instanceof Expr\Array_
                        ? $finder->findInstanceOf($assignment->var, Expr\Variable::class)
                        : []
                );
            foreach ($destinations as $var) {
                if (is_string($var->name) && !isset($this->locals[$var->name])) {
                    $names[$var->name] = true;
                }
            }
        }
        return (
            $names !== []
            && $finder->findFirst(
                $tail,
                static fn(Node $node): bool => (
                    $node instanceof Expr\Variable
                    && is_string($node->name)
                    && isset($names[$node->name])
                ),
            ) !== null
        );
    }

    /** @param list<Stmt> $tail */
    private function conditional(Stmt\If_ $stmt, string $pad, array $tail = []): string
    {
        $out = '';
        foreach ([$stmt, ...$stmt->elseifs] as $branch) {
            $cond = $this->expect($branch->cond, new Type('bool'));
            $out .= "{$pad}if $cond->code then\n";
            $out .= $this->nested($this->continued($branch->stmts, $tail), "$pad  ");
            if ($branch !== $stmt || $stmt->elseifs !== [] || $stmt->else !== null || $tail !== []) {
                $out .= "{$pad}else\n";
                $pad .= '  ';
            }
        }
        $other = $this->continued($stmt->else->stmts ?? [], $tail);
        if ($other !== [] || $stmt->elseifs !== [] || $stmt->else !== null) {
            $out .= $this->nested($other, $pad);
        }
        return $out;
    }

    /**
     * @param array<Stmt> $stmts
     * @param list<Stmt> $tail
     * @return list<Stmt>
     */
    private function continued(array $stmts, array $tail): array
    {
        $last = end($stmts);
        return (
            $this->returns($stmts) || $last instanceof Stmt\Break_ || $last instanceof Stmt\Continue_
                ? array_values($stmts)
                : [...array_values($stmts), ...$tail]
        );
    }

    private function loop(Stmt\For_|Stmt\While_ $stmt, string $pad): string
    {
        $prefix = $stmt instanceof Stmt\For_ ? $this->updates($stmt->init, $pad) : '';
        $inner = "$pad  ";
        $steps = $stmt instanceof Stmt\For_ ? $stmt->loop : [];
        $conds = $stmt instanceof Stmt\For_ ? $stmt->cond : [$stmt->cond];
        $last = array_pop($conds);
        $test = $this->updates($conds, $inner);
        if ($last !== null) {
            $cond = $this->expect($last, new Type('bool'));
            $test .= "{$inner}if !$cond->code then\n{$inner}  break\n";
        }
        $this->loops[] = $steps;
        $body = $this->nested($stmt->stmts, $inner);
        array_pop($this->loops);
        return "$prefix{$pad}repeat\n$test$body" . $this->updates($steps, $inner);
    }

    private function foreach(Stmt\Foreach_ $stmt, string $pad): string
    {
        $items = $this->value($stmt->expr);
        if (
            $stmt->byRef
            || $items->type->kind !== 'list'
            || !$stmt->valueVar instanceof Expr\Variable
            || $stmt->keyVar !== null && !$stmt->keyVar instanceof Expr\Variable
        ) {
            $this->fail($stmt, 'expected a by-value foreach over a list');
        }
        $locals = $this->locals;
        $lists = $this->lists;
        $inner = "$pad  ";
        $item = $this->fresh();
        $dest = $this->variable($stmt->valueVar);
        $key = $this->fresh();
        $assign = '';
        $head = "{$pad}for $item in $items->code do\n";
        if ($stmt->keyVar !== null) {
            $head = "{$pad}for ($item, $key) in ($items->code).zipIdx do\n";
            $assign .= $this->assign(
                $this->variable($stmt->keyVar),
                new Value("(Int.ofNat $key)", new Type('int')),
                $stmt,
                $inner,
            );
        }
        $assign .= $this->assign($dest, new Value($item, $items->type->at(0)), $stmt, $inner);
        $this->loops[] = [];
        $body = $this->statements($stmt->stmts, $inner);
        array_pop($this->loops);
        $this->locals = $locals;
        $this->lists = array_intersect_key($lists, $this->lists);
        return $head . $assign . $body;
    }

    /** @param array<Expr> $exprs */
    private function updates(array $exprs, string $pad): string
    {
        $out = '';
        foreach ($exprs as $expr) {
            $out .= $this->expressionStatement($expr, $pad);
        }
        return $out;
    }

    private function expressionStatement(Expr $expr, string $pad): string
    {
        if ($expr instanceof Expr\Assign) {
            if ($expr->var instanceof Expr\Variable) {
                $name = $this->variable($expr->var);
                $value = $this->value($expr->expr, $this->locals[$name] ?? null);
                $code = $this->assign($name, $value, $expr, $pad);
                if ($expr->expr instanceof Expr\Array_ && $value->type->kind === 'list') {
                    $this->lists[$name] = true;
                }
                return $code;
            }
            if (
                $expr->var instanceof Expr\ArrayDimFetch
                && $expr->var->dim === null
                && $expr->var->var instanceof Expr\Variable
            ) {
                $name = $this->variable($expr->var->var);
                $list = $this->locals[$name] ?? null;
                if ($list === null || $list->kind !== 'list' || !isset($this->lists[$name])) {
                    $this->fail($expr, 'append requires a list constructed locally');
                }
                if ($list->at(0)->kind === 'unknown') {
                    $value = $this->value($expr->expr);
                    if ($value->type->kind === 'null') {
                        $this->fail($expr, 'append to an empty list needs a typed value');
                    }
                    $this->locals[$name] = new Type('list', [$value->type]);
                } else {
                    $value = $this->expect($expr->expr, $list->at(0));
                }
                $var = self::ident($name);
                return "$pad$var := $var ++ [$value->code]\n";
            }
            if ($expr->var instanceof Expr\List_ || $expr->var instanceof Expr\Array_) {
                return $this->unpack($expr, $expr->var, $pad);
            }
            $this->fail($expr, 'unsupported assignment target');
        }
        if ($expr instanceof Expr\AssignOp && $expr->var instanceof Expr\Variable) {
            $op = match ($expr::class) {
                Expr\AssignOp\Plus::class => '+',
                Expr\AssignOp\Minus::class => '-',
                Expr\AssignOp\Mul::class => '*',
                Expr\AssignOp\Concat::class => '.',
                default => $this->fail($expr, 'unsupported compound assignment'),
            };
            $name = $this->variable($expr->var);
            return $this->assign(
                $name,
                $this->binary($op, $this->value($expr->var), $this->value($expr->expr), $expr),
                $expr,
                $pad,
            );
        }
        if (
            (
                $expr instanceof Expr\PostInc
                || $expr instanceof Expr\PreInc
                || $expr instanceof Expr\PostDec
                || $expr instanceof Expr\PreDec
            )
            && $expr->var instanceof Expr\Variable
        ) {
            $name = $this->variable($expr->var);
            $value = $this->expect($expr->var, new Type('int'));
            $op = $expr instanceof Expr\PostInc || $expr instanceof Expr\PreInc ? 'add' : 'sub';
            return $this->assign($name, $this->lift("Php.$op $value->code 1", $value->type), $expr, $pad);
        }
        if ($expr instanceof Expr\Throw_) {
            return "{$pad}return " . $this->thrown($expr, $this->result)->code . "\n";
        }
        $value = $this->value($expr);
        return "{$pad}let _ := $value->code\n";
    }

    private function unpack(Expr\Assign $expr, Expr\Array_|Expr\List_ $lhs, string $pad): string
    {
        $right = $expr->expr;
        if ($right instanceof Expr\Array_ && count($right->items) === 2) {
            [$first, $second] = $right->items;
            $types = new Type('pair', [$this->value($first->value)->type, $this->value($second->value)->type]);
            $value = $this->array($right, $types);
        } else {
            $value = $this->value($right);
        }
        if ($value->type->kind !== 'pair' || count($lhs->items) !== 2) {
            $this->fail($expr, 'destructuring requires a two-element tuple');
        }
        $temp = $this->fresh();
        $out = "{$pad}let $temp := $value->code\n";
        foreach ($lhs->items as $i => $item) {
            if (
                $item === null
                || !$item->value instanceof Expr\Variable
                || $item->key !== null
                || $item->byRef
                || $item->unpack
            ) {
                $this->fail($expr, 'expected two by-value variables in tuple destructuring');
            }
            $var = $this->variable($item->value);
            $out .= $this->assign($var, new Value("$temp." . ($i + 1), $value->type->at($i)), $expr, $pad);
        }
        return $out;
    }

    private function fresh(): string
    {
        return self::ident('%' . $this->next++);
    }

    private function assign(string $name, Value $value, Node $at, string $pad): string
    {
        $var = self::ident($name);
        $previous = $this->locals[$name] ?? null;
        unset($this->lists[$name]);
        if ($previous !== null) {
            $value = $this->convert($value, $previous, $at);
            return "$pad$var := $value->code\n";
        }
        if ($value->type->kind === 'null') {
            $this->fail($at, 'null needs a nullable type');
        }
        $this->locals[$name] = $value->type;
        $unknownList = $value->type->kind === 'list' && $value->type->at(0)->kind === 'unknown';
        $annotation = $unknownList ? '' : ' : ' . $value->type->lean();
        return "{$pad}let mut $var$annotation := $value->code\n";
    }

    private function expect(Expr $expr, Type $type): Value
    {
        return $this->convert($this->value($expr, $type), $type, $expr);
    }

    private function convert(Value $value, Type $type, Node $at): Value
    {
        if ($type == $value->type) {
            return $value;
        }
        if ($type->kind === 'list' && $value->type->kind === 'list' && $value->type->at(0)->kind === 'unknown') {
            return new Value($value->code, $type, $value->effect);
        }
        if ($type->kind === 'option') {
            if ($value->type->kind === 'null') {
                return new Value('none', $type);
            }
            if ($type->at(0) == $value->type) {
                return new Value("(some $value->code)", $type, $value->effect);
            }
        }
        if ($type->kind === 'int' && $value->type->kind === 'nat') {
            return new Value("(Int.ofNat $value->code)", $type, $value->effect);
        }
        if ($type->kind === 'float' && $value->type->kind === 'int') {
            return new Value("(Int.toFloat $value->code)", $type, $value->effect);
        }
        $this->fail($at, "expected $type->kind, got {$value->type->kind}");
    }

    private function lift(string $term, Type $type): Value
    {
        $this->fails = true;
        return new Value("(← $term)", $type, effect: true);
    }

    private function value(Expr $expr, ?Type $expected = null): Value
    {
        if ($expr instanceof Expr\Variable) {
            $name = $this->variable($expr);
            $type = $this->locals[$name] ?? $this->fail($expr, "uninitialized or branch-local variable \$$name");
            return new Value(self::ident($name), $type);
        }
        if ($expr instanceof Node\Scalar\Int_) {
            return new Value("($expr->value : Int)", new Type('int'));
        }
        if ($expr instanceof Node\Scalar\Float_) {
            if (!is_finite($expr->value)) {
                $this->fail($expr, 'nonfinite float literal');
            }
            $literal = json_encode($expr->value, JSON_THROW_ON_ERROR | JSON_PRESERVE_ZERO_FRACTION);
            return new Value("($literal : Float)", new Type('float'));
        }
        if ($expr instanceof Node\Scalar\String_) {
            return new Value($this->string($expr->value, $expr), new Type('string'));
        }
        if ($expr instanceof Expr\ConstFetch) {
            $constant = $expr->name->toString();
            $keyword = strtolower($constant);
            if ($keyword === 'true' || $keyword === 'false') {
                return new Value($keyword, new Type('bool'));
            }
            return match ($constant) {
                'PHP_INT_MIN' => new Value('(-9223372036854775808 : Int)', new Type('int')),
                'PHP_INT_MAX' => new Value('(9223372036854775807 : Int)', new Type('int')),
                default => $keyword === 'null'
                    ? new Value('none', new Type('null'))
                    : $this->fail($expr, 'unsupported constant'),
            };
        }
        if ($expr instanceof Expr\Array_) {
            return $this->array($expr, $expected);
        }
        if ($expr instanceof Expr\ArrayDimFetch) {
            return $this->index($expr);
        }
        if ($expr instanceof Expr\BinaryOp) {
            $op = $expr->getOperatorSigil();
            if (!in_array($op, ['+', '-', '*', '/', '%', '.', '===', '!==', '<', '<=', '>', '>=', '&&', '||'], true)) {
                $this->fail($expr, "unsupported operator $op");
            }
            return $this->binary($op, $this->value($expr->left), $this->value($expr->right), $expr);
        }
        if ($expr instanceof Expr\BooleanNot) {
            $value = $this->expect($expr->expr, new Type('bool'));
            return new Value("(!$value->code)", $value->type, $value->effect);
        }
        if ($expr instanceof Expr\UnaryMinus) {
            $value = $this->value($expr->expr);
            return match ($value->type->kind) {
                'int' => $this->lift("Php.neg $value->code", $value->type),
                'float' => new Value("(-$value->code)", $value->type, $value->effect),
                default => $this->fail($expr, 'unary minus expects an integer or float'),
            };
        }
        if ($expr instanceof Expr\Ternary) {
            $cond = $this->expect($expr->cond, new Type('bool'));
            $yes = $expr->if === null ? new Value('true', $cond->type) : $this->value($expr->if, $expected);
            $no = $this->expect($expr->else, $expected ?? $yes->type);
            return $this->choose($cond, $this->convert($yes, $no->type, $expr), $no);
        }
        if ($expr instanceof Expr\Match_) {
            return $this->match($expr, $expected);
        }
        if ($expr instanceof Expr\Throw_) {
            return $this->thrown($expr, $expected ?? $this->result);
        }
        if ($expr instanceof Expr\FuncCall || $expr instanceof Expr\StaticCall) {
            return $this->call($expr);
        }
        if ($expr instanceof Expr\PropertyFetch && $expr->name instanceof Node\Identifier) {
            $base = $this->value($expr->var);
            $name = $expr->name->toString();
            $fields = $this->objects->fields($base->type);
            $type = $fields[$name] ?? $this->fail($expr, "unsupported property $name");
            return new Value("($base->code)." . self::ident($name), $type, $base->effect);
        }
        if (
            $expr instanceof Expr\ClassConstFetch
            && $expr->class instanceof Node\Name
            && $expr->name instanceof Node\Identifier
        ) {
            $type = $this->object($expr->class);
            $case = $expr->name->toString();
            if ($type->kind !== 'enum' || !in_array($case, $this->objects->cases($type), true)) {
                $this->fail($expr, 'expected a backed enum case');
            }
            return new Value($type->lean() . '.' . self::ident($case), $type);
        }
        if ($expr instanceof Expr\New_ && $expr->class instanceof Node\Name) {
            return $this->construct($expr);
        }
        $this->fail($expr, 'unsupported expression ' . $expr->getType());
    }

    private function string(string $value, Node $at): string
    {
        if (preg_match('//u', $value) !== 1) {
            $this->fail($at, 'string literal must be valid UTF-8');
        }
        $value = strtr($value, ['"' => '\\"', '\\' => '\\\\', "\n" => '\\n', "\r" => '\\r', "\t" => '\\t']);
        $value = preg_replace_callback(
            '/[\x00-\x1f\x7f]/',
            static fn(array $m): string => sprintf('\\x%02x', ord($m[0])),
            $value,
        );
        return '"' . $value . '"';
    }

    private function array(Expr\Array_ $expr, ?Type $type): Value
    {
        if ($type?->kind === 'option') {
            $type = $type->at(0);
        }
        if ($type === null && count($expr->items) === 2) {
            [$first, $second] = $expr->items;
            $a = $this->value($first->value);
            $b = $this->value($second->value);
            if ($first->key !== null || $a->type != $b->type) {
                $type = new Type('pair', [$a->type, $b->type]);
            }
        }
        if ($type === null && $expr->items === []) {
            return new Value('[]', new Type('list', [new Type('unknown')]));
        }
        $values = [];
        foreach ($expr->items as $i => $item) {
            if (
                $item->unpack
                || $item->byRef
                || $item->key !== null && (!$item->key instanceof Node\Scalar\Int_ || $item->key->value !== $i)
            ) {
                $this->fail($item, 'expected a zero-based array literal without references or unpacking');
            }
            $element = match ($type?->kind) {
                'list' => $type->at(0),
                'pair' => $type->args[$i] ?? $this->fail($item, 'too many tuple elements'),
                default => $values[0]->type ?? null,
            };
            $values[] = $element === null ? $this->value($item->value) : $this->expect($item->value, $element);
        }
        if ($type === null) {
            if ($values[0]->type->kind === 'null') {
                $this->fail($expr, 'array literal needs an element type');
            }
            $type = new Type('list', [$values[0]->type]);
        }
        $parts = implode(', ', array_map(static fn(Value $value): string => $value->code, $values));
        $code = match ($type->kind) {
            'list' => "([$parts] : {$type->lean()})",
            'pair' => count($values) === 2 ? "($parts)" : $this->fail($expr, 'expected a two-element tuple'),
            default => $this->fail($expr, 'array literal requires a list or tuple type'),
        };
        return new Value($code, $type, array_any($values, static fn(Value $value): bool => $value->effect));
    }

    private function index(Expr\ArrayDimFetch $expr): Value
    {
        $base = $this->value($expr->var);
        $dim = $expr->dim;
        if ($dim !== null && $base->type->kind === 'list') {
            $index = $this->expect($dim, new Type('int'));
            return $this->lift("Php.getItem $base->code $index->code", $base->type->at(0));
        }
        if (
            $base->type->kind === 'pair'
            && $dim instanceof Node\Scalar\Int_
            && ($dim->value === 0 || $dim->value === 1)
        ) {
            return new Value("($base->code)." . ($dim->value + 1), $base->type->at($dim->value), $base->effect);
        }
        $this->fail($expr, 'unsupported subscript');
    }

    private function binary(string $op, Value $a, Value $b, Node $at): Value
    {
        $effect = $a->effect || $b->effect;
        $bool = new Type('bool');
        if ($op === '===' || $op === '!==') {
            $test = $this->equality($a, $b, $at);
            return new Value($op === '===' ? $test : "(!$test)", $bool, $effect);
        }
        if ($op === '&&' || $op === '||') {
            if ($a->type->kind !== 'bool' || $b->type->kind !== 'bool') {
                $this->fail($at, "$op expects bool operands");
            }
            if ($b->effect) {
                $constant = new Value($op === '&&' ? 'false' : 'true', $bool);
                return $op === '&&' ? $this->choose($a, $b, $constant) : $this->choose($a, $constant, $b);
            }
            return new Value("($a->code $op $b->code)", $bool, $effect);
        }
        $kind = $a->type->kind;
        if ($a->type != $b->type) {
            $this->fail($at, "$op expects operands of the same type");
        }
        if ($op === '.' && $kind === 'string') {
            return new Value("(Php.concat $a->code $b->code)", $a->type, $effect);
        }
        if (in_array($op, ['<', '<=', '>', '>='], true)) {
            if (in_array($kind, ['int', 'nat', 'bool'], true)) {
                return new Value("(decide ($a->code $op $b->code))", $bool, $effect);
            }
            if ($kind === 'float') {
                return new Value("(decide ($a->code $op $b->code))", $bool, $effect);
            }
            $this->fail($at, "unsupported operands for $op");
        }
        if ($kind === 'int') {
            $name = match ($op) {
                '+' => 'add',
                '-' => 'sub',
                '*' => 'mul',
                '%' => 'mod',
                default => $this->fail($at, 'integer division / is outside the subset; use intdiv'),
            };
            return $this->lift("Php.$name $a->code $b->code", $a->type);
        }
        if ($kind === 'float') {
            if ($op === '/') {
                return $this->lift("Php.fdiv $a->code $b->code", $a->type);
            }
            if (in_array($op, ['+', '-', '*'], true)) {
                return new Value("($a->code $op $b->code)", $a->type, $effect);
            }
        }
        $this->fail($at, "unsupported operands for $op");
    }

    private function equality(Value $a, Value $b, Node $at): string
    {
        if ($a->type->kind === 'null' && $b->type->kind === 'null') {
            return 'true';
        }
        if ($a->type->kind === 'null' && $b->type->kind === 'option') {
            return "(Php.isNull $b->code)";
        }
        if ($b->type->kind === 'null' && $a->type->kind === 'option') {
            return "(Php.isNull $a->code)";
        }
        if ($a->type == $b->type) {
            if ($a->type->kind === 'enum') {
                $cases = $this->objects->cases($a->type);
                $arms = array_map(
                    static fn(string $case): string => (
                        '| .' . self::ident($case) . ', .' . self::ident($case) . ' => true'
                    ),
                    $cases,
                );
                return (
                    "(match $a->code, $b->code with "
                    . implode(' ', $arms)
                    . (count($cases) === 1 ? ')' : ' | _, _ => false)')
                );
            }
            if (in_array($a->type->kind, ['int', 'nat', 'float', 'bool', 'string'], true)) {
                return "($a->code == $b->code)";
            }
        }
        $this->fail(
            $at,
            'strict comparison requires same-type scalar or enum operands, or nullable compared with null',
        );
    }

    private function choose(Value $cond, Value $yes, Value $no): Value
    {
        if ($yes->effect || $no->effect) {
            return $this->lift("(if $cond->code then do pure $yes->code else do pure $no->code)", $yes->type);
        }
        return new Value("(if $cond->code then $yes->code else $no->code)", $yes->type, $cond->effect);
    }

    private function match(Expr\Match_ $expr, ?Type $expected): Value
    {
        $subject = $this->value($expr->cond);
        $temp = $this->fresh();
        $read = new Value($temp, $subject->type);
        $default = null;
        $arms = [];
        foreach ($expr->arms as $arm) {
            $value = $expected === null ? $this->value($arm->body) : $this->expect($arm->body, $expected);
            $expected ??= $value->type;
            if ($arm->conds === null) {
                $default = $value;
                continue;
            }
            $cond = new Value('false', new Type('bool'));
            foreach (array_reverse($arm->conds) as $case) {
                $candidate = $this->value($case);
                $test = new Value($this->equality($read, $candidate, $case), new Type('bool'), $candidate->effect);
                $cond = $this->choose($test, new Value('true', new Type('bool')), $cond);
            }
            $arms[] = [$cond, $value];
        }
        $expected ??= $this->result;
        $out = $default ?? $this->lift('throw Php.Exc.unhandledMatch', $expected);
        foreach (array_reverse($arms) as [$cond, $value]) {
            $out = $this->choose($cond, $value, $out);
        }
        if ($out->effect) {
            return $this->lift("(do let $temp := $subject->code; pure $out->code)", $out->type);
        }
        return new Value("(let $temp := $subject->code; $out->code)", $out->type, $subject->effect);
    }

    private function thrown(Expr\Throw_ $expr, Type $type): Value
    {
        if (
            !$expr->expr instanceof Expr\New_
            || !$expr->expr->class instanceof Node\Name
            || $expr->expr->isFirstClassCallable()
        ) {
            $this->fail($expr, 'expected throw new ExceptionClass(...)');
        }
        $name = $this->className($expr->expr->class);
        if (!class_exists($name, false) || !is_subclass_of($name, \Throwable::class)) {
            $this->fail($expr, 'expected a built-in exception class');
        }
        $exception = new \ReflectionClass($name);
        if (
            !$exception->isInternal()
            || !in_array(
                $exception->getConstructor()?->getDeclaringClass()->getName(),
                [\Exception::class, \Error::class],
                true,
            )
        ) {
            $this->fail($expr, 'exception constructor is outside the subset');
        }
        $args = $this->arguments($expr->expr->getArgs());
        if (count($args) > 3) {
            $this->fail($expr, 'exception constructor accepts at most three arguments');
        }
        $let = '';
        foreach ($args as $i => $arg) {
            $value = $this->value($arg);
            if ($value->type->kind !== ['string', 'int', 'null'][$i]) {
                $this->fail($arg, 'expected string message, integer code or null previous exception');
            }
            if ($value->type->kind !== 'null') {
                $let .= "let _ := $value->code; ";
            }
        }
        $class = $this->string($exception->getName(), $expr->expr->class);
        return $this->lift("(do {$let}throw (Php.Exc.thrown $class))", $type);
    }

    private function object(Node\Name $name): Type
    {
        try {
            return $this->objects->type($this->className($name));
        } catch (RuntimeException $error) {
            $this->fail($name, $error->getMessage());
        }
    }

    private function construct(Expr\New_ $expr): Value
    {
        if (!$expr->class instanceof Node\Name || $expr->isFirstClassCallable()) {
            $this->fail($expr, 'expected a static class name');
        }
        $type = $this->object($expr->class);
        $fields = $this->objects->fields($type);
        if (!$this->objects->constructible($type) || count($fields) !== count($expr->getArgs())) {
            $this->fail($expr, 'expected a structural constructor with all fields and no unchecked invariants');
        }
        $values = [];
        foreach ($this->arguments($expr->getArgs()) as $i => $arg) {
            $values[] = $this->expect($arg, array_values($fields)[$i]);
        }
        $checks = $this->objects->invariants($type);
        if ($checks === []) {
            return $this->application($type->lean() . '.mk', $values, $type);
        }
        $evaluate = '';
        $bind = '';
        $record = [];
        foreach (array_keys($fields) as $index => $field) {
            $temp = $this->fresh();
            $id = self::ident($field);
            $evaluate .= "let $temp := {$values[$index]->code}; ";
            $bind .= "let $id := $temp; ";
            $record[] = "$id := $id";
        }
        foreach ($checks as $check) {
            $id = self::ident($check['field']);
            $record[] = "$id := $id";
        }
        $fieldsCode = implode(', ', $record);
        $term = "pure ({ $fieldsCode } : {$type->lean()})";
        $class = $this->string(\Conao3\Leanfran\ValidationError::class, $expr);
        $error = "throw (Php.Exc.thrown $class)";
        foreach (array_reverse($checks) as $check) {
            $id = self::ident($check['field']);
            $predicate = $check['prop'];
            $term = "if $id : $predicate then $term else $error";
        }
        return $this->lift("(do $evaluate$bind$term)", $type);
    }

    /** @param array<Node\Arg> $args
     * @return list<Expr>
     */
    private function arguments(array $args): array
    {
        $out = [];
        foreach ($args as $arg) {
            if ($arg->unpack || $arg->byRef || $arg->name !== null) {
                $this->fail($arg, 'expected positional, by-value arguments');
            }
            $out[] = $arg->value;
        }
        return $out;
    }

    private function call(Expr\FuncCall|Expr\StaticCall $expr): Value
    {
        if (
            $expr->isFirstClassCallable()
            || !$expr->name instanceof Node\Name && !$expr->name instanceof Node\Identifier
        ) {
            $this->fail($expr, 'dynamic calls are outside the subset');
        }
        $name = strtolower($expr->name->toString());
        $args = $this->arguments($expr->getArgs());
        $resolved = $name;
        if ($expr instanceof Expr\StaticCall) {
            if (
                !$expr->class instanceof Node\Name
                || !$expr->name instanceof Node\Identifier
                || strtolower($expr->class->toString()) === 'static'
            ) {
                $this->fail($expr, 'expected a statically resolved method');
            }
            $resolved = strtolower($this->className($expr->class)) . "\\$name";
        } elseif ($expr->name instanceof Node\Name && $expr->name->isUnqualified() && $this->model->namespace !== '') {
            $resolved = strtolower($this->model->namespace) . "\\$name";
        }
        if ($resolved !== $name && $expr instanceof Expr\FuncCall && !isset($this->functions[$resolved])) {
            $resolved = $name;
        }
        try {
            $target = ($this->target)($resolved);
        } catch (TranslateError $error) {
            $this->fail($expr, "cannot call $resolved: {$error->getMessage()}");
        }
        if ($target !== null) {
            if (count($args) !== count($target->parameters)) {
                $this->fail($expr, 'modeled call must pass every parameter');
            }
            $this->dependencies[$resolved] = true;
            $values = array_map($this->expect(...), $args, array_values($target->parameters));
            $label = '_root_.' . self::leanName($target->model->lean());
            return $target->fails
                ? $this->lift($label . $this->terms($values), $target->result)
                : $this->application($label, $values, $target->result);
        }
        if ($expr instanceof Expr\StaticCall) {
            $this->fail($expr, "call to unmodeled method $resolved");
        }
        if (isset($this->functions[$resolved])) {
            $this->fail($expr, "call to unmodeled function $resolved");
        }
        return $this->builtin($name, $args, $expr);
    }

    /** @param list<Expr> $args */
    private function builtin(string $name, array $args, Node $at): Value
    {
        $arity = self::BUILTINS[$name] ?? $this->fail($at, "call to unmodeled function $name");
        if (count($args) !== $arity) {
            $this->fail($at, "$name expects $arity arguments in the subset");
        }
        $a = $this->value($args[0]);
        $int = new Type('int');
        if ($name === 'strlen' && $a->type->kind === 'string' || $name === 'count' && $a->type->kind === 'list') {
            return $this->application("Php.$name", [$a], $int);
        }
        if ($name === 'count' && $a->type->kind === 'pair') {
            return new Value("(let _ := $a->code; (2 : Int))", $int, $a->effect);
        }
        if ($name === 'abs') {
            return match ($a->type->kind) {
                'int' => $this->lift("Php.abs $a->code", $int),
                'float' => $this->application('Float.abs', [$a], $a->type),
                default => $this->fail($at, 'abs expects int or float'),
            };
        }
        if ($name === 'intdiv' && $a->type->kind === 'int') {
            $b = $this->expect($args[1], $int);
            return $this->lift("Php.intdiv $a->code $b->code", $int);
        }
        if (in_array($name, ['min', 'max'], true) && in_array($a->type->kind, ['int', 'float'], true)) {
            $b = $this->expect($args[1], $a->type);
            $operator = $a->type->kind === 'float' ? "Php.{$name}Float" : $name;
            return $this->application($operator, [$a, $b], $a->type);
        }
        $this->fail($at, "unsupported arguments to $name");
    }

    /** @param list<Value> $values */
    private function application(string $name, array $values, Type $type): Value
    {
        return new Value(
            '(' . $name . $this->terms($values) . ')',
            $type,
            array_any($values, static fn(Value $v): bool => $v->effect),
        );
    }

    /** @param list<Value> $values */
    private function terms(array $values): string
    {
        return $values === []
            ? ''
            : ' ' . implode(' ', array_map(static fn(Value $value): string => $value->code, $values));
    }
}
