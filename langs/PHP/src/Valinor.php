<?php

declare(strict_types=1);

namespace Conao3\Leanfran;

use CuyZ\Valinor\Mapper\Tree\Message\ErrorMessage;
use CuyZ\Valinor\Mapper\Tree\Message\MessageBuilder;
use CuyZ\Valinor\MapperBuilder;

/** Integrates generated Lean types with Valinor's mapper. */
final class Valinor
{
    /** Collect Lean validation errors as mapping messages. */
    public static function configure(MapperBuilder $builder): MapperBuilder
    {
        return $builder->filterExceptions(static function (\Throwable $error): ErrorMessage {
            if ($error instanceof ValidationError) {
                return MessageBuilder::from($error);
            }
            throw $error;
        });
    }
}
