<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Tests\Embed;

use Conao3\Leanfran\Embed\Scanner;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use RuntimeException;

final class ScannerTest extends TestCase
{
    public function testReadsAllClassesWithoutExecutingTheFile(): void
    {
        $php = <<<'PHP_SOURCE'
            <?php
            declare(strict_types=1);
            namespace App {
                use Conao3\Leanfran\{Lean as Proof, function nope};
                use Library\Input as Model;
                throw new \RuntimeException('PHP was executed');
                #[Other(#[Nested] fn() => 0)]
                function ignored(): void {}
                #[Other('ignored'), Proof(
                    imports: ["Std", \Std\Data\HashMap::class],
                    uses: [First::class, namespace\Third::class, Model::class, '\GlobalClass'],
                    models: [],
                    source: <<<'LEAN'
                        def x := 1
                          -- $x \n
                        LEAN
                )]
                final class First {
                    use SomeTrait;
                }
                #[\Conao3\Leanfran\Lean('def y := "it\'s \\ fine"')]
                final readonly class Second {}
            }
            namespace Elsewhere {
                #[Lean('ignored')]
                class Third {}
                use Conao3\Leanfran as Runtime;
                #[runtime\lean('def z := 3')]
                class Fourth {}
            }
            PHP_SOURCE;
        $blocks = Scanner::scan('src/Many.php', str_replace("\n", "\r\n", $php));
        self::assertSame(['App\\First', 'App\\Second', 'Elsewhere\\Fourth'], array_column($blocks, 'name'));
        [$first, $second] = $blocks;
        self::assertSame('src/First', $first->output);
        self::assertSame(['Std', 'Std.Data.HashMap'], $first->imports);
        self::assertSame(['App\\First', 'App\\Third', 'Library\\Input', 'GlobalClass'], $first->uses);
        self::assertSame("def x := 1\n  -- \$x \\n", $first->source->text);
        self::assertSame(14, $first->source->line);
        self::assertSame(str_repeat(' ', 12), $first->source->indent);
        self::assertSame([15, 15], $first->source->position(2, 2));
        self::assertSame('def y := "it\'s \\ fine"', $second->source->text);
        self::assertSame(21, $second->source->line);
        $line = explode("\n", $php)[20];
        self::assertSame([21, (int) strpos($line, 'fine') + 1], $second->source->position(1, 17));
    }

    /** @return iterable<string, array{string, string}> */
    public static function invalidInputs(): iterable
    {
        yield 'heredoc' => ["<<<LEAN\ndef x := 0\nLEAN", 'source must be a nowdoc or a single-quoted literal'];
        yield 'concatenation' => ["'first' . 'second'", 'source must be a nowdoc or a single-quoted literal'];
        yield 'constant' => ['VALUE', 'source must be a nowdoc or a single-quoted literal'];
        yield 'double quotes' => ['"def x := 0"', 'source must be a nowdoc or a single-quoted literal'];
        yield 'nonempty models' => ["'def x := 0', models: [Item::class]", 'non-empty Lean $models is not supported'];
        yield 'computed use' => [
            "'def x := 0', uses: [Item::class . 'Other']",
            'expected a string or X::class literal',
        ];
        yield 'bad import' => ["'def x := 0', imports: ['Std\nopen Hidden']", 'invalid Lean import'];
        yield 'duplicate' => ["'def x := 0')] #[Lean('def y := 0'", 'duplicate Lean attribute'];
    }

    #[DataProvider('invalidInputs')]
    public function testRejectsUnsupportedArguments(string $argument, string $message): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessageMatches('~^Input\.php:3:[0-9]+: .*' . preg_quote($message, '~') . '~');
        Scanner::scan('Input.php', "<?php\nuse Conao3\\Leanfran\\Lean;\n#[Lean($argument)] class Input {}");
    }

    public function testForeignAttributeAndAnonymousClassAreIgnored(): void
    {
        $php = <<<'PHP_SOURCE'
            <?php
            namespace App;
            use Other\Lean;
            #[Lean(NONSOURCE)]
            class Foreign {}
            $anonymous = new #[\Conao3\Leanfran\Lean(NONSOURCE)] class {};
            PHP_SOURCE;
        self::assertSame([], Scanner::scan('src/Foreign.php', $php));
    }
}
