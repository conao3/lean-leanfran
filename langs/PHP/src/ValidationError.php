<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

/** Reports invalid values at the PHP boundary. */
final class ValidationError extends \InvalidArgumentException
{
    /** @param non-empty-list<LeanIssue> $issues */
    public function __construct(
        public readonly array $issues,
    ) {
        $issue = $issues[0];
        $path = implode('.', $issue['path']);
        parent::__construct($path === '' ? $issue['message'] : $path . ': ' . $issue['message']);
    }
}
