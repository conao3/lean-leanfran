<?php

declare(strict_types=1);

namespace Conao3\Leanfran\Embed;

/** A class with a statically read Lean attribute. */
final readonly class Block
{
    public string $module;
    public string $output;

    /**
     * @param list<string> $imports
     * @param list<string> $models
     * @param list<string> $uses
     */
    public function __construct(
        public string $name,
        public string $file,
        public int $line,
        public int $column,
        public Source $source,
        public array $imports,
        public array $uses,
        public array $models,
    ) {
        $this->module = 'LeanPhpEmbed.B' . bin2hex($name);
        $this->output = dirname($file) . '/' . substr($name, (int) strrpos('\\' . $name, '\\'));
    }

    /** Returns the attribute location. */
    public function location(): string
    {
        return "$this->file:$this->line:$this->column";
    }
}
