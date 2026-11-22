<?php

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

final class SkippedTest extends TestCase
{
    public function testSkippedReasons(): void
    {
        $summary = publicSummary('skipped');
        $reasons = array_column($summary['skipped'], 'reason', 'name');
        foreach ([
            'nested' => 'ambiguous `Option`',
            'nullable' => 'ambiguous `Option`',
            'Indexed' => 'indexed type',
            'indexed' => 'indexed type',
            'Witness' => 'type class',
            'aClass' => 'type class',
            'Proof' => 'proposition',
            'hiddenType' => 'private type',
            'hidden' => 'private definition',
            'TypeField' => 'type field',
            'Undecidable' => 'no `Decidable` instance',
            'bytes' => 'unsupported type',
            'thunk' => 'unsupported type',
            'task' => 'unsupported type',
            'library' => 'unsupported type',
            'metaprogram' => 'unsupported type',
            'path' => 'unsupported type',
            'ioError' => 'unsupported type',
            'generic' => 'polymorphic',
            'higher' => 'function type',
            'proofArg' => 'takes a proof argument',
        ] as $name => $reason) {
            $name = 'LeanPhpTest.PublicSkipped.' . $name;
            self::assertArrayHasKey($name, $reasons);
            self::assertStringContainsString($reason, $reasons[$name], $name);
        }
        self::assertNotEmpty(array_filter($reasons, static fn(string $reason): bool => str_contains(
            $reason,
            'private type',
        )));
        self::assertSame(
            ['PublicSkipped.php', 'LeanLeanPhpTest_PublicSkipped.php'],
            array_map(basename(...), $summary['files']),
        );
    }
}
