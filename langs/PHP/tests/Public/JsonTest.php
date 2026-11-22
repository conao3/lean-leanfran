<?php

declare(strict_types=1);

use App\Lean\Json\Big;
use App\Lean\Json\Color;
use App\Lean\Json\Data;
use App\Lean\Json\Json as JsonFacade;
use App\Lean\Json\ShapeFixed;
use App\Lean\Json\ShapeNone;
use App\Lean\Json\ShapePair;
use App\Lean\Json\ShapePositional;
use Conao3\Leanfran\Json;
use Conao3\Leanfran\ValidationError;
use PHPUnit\Framework\TestCase;

final class JsonTest extends TestCase
{
    public function testNativeOracle(): void
    {
        $oracle = file(__DIR__ . '/../../test-out/public/oracle-json', FILE_IGNORE_NEW_LINES);
        self::assertIsArray($oracle);
        $php = [
            JsonFacade::big(),
            ...JsonFacade::data(),
            ...JsonFacade::shapes(),
            ...JsonFacade::colors(),
            ...JsonFacade::trees(),
        ];
        self::assertCount(count($php), $oracle);
        foreach ($php as $i => $value) {
            $type = $value::class;
            $json = $value->toJson();
            self::assertSame(self::canonical($oracle[$i]), self::canonical($json));
            self::assertSame($json, $type::fromJson($json)->toJson());
            self::assertSame($json, $type::fromJson($oracle[$i])->toJson());
            self::assertSame($json, $type::fromArray($value->toArray())->toJson());
        }

        $big = '1267650600228229401496703205376';
        $json = '{"n":' . $big . '}';
        $fromDigits = new Big($big);
        $fromGmp = new Big(gmp_init($big, 10));
        $fromJson = Big::fromJson($json);
        self::assertSame($json, $oracle[0]);
        foreach ([$fromDigits, $fromGmp, $fromJson] as $value) {
            self::assertInstanceOf(GMP::class, $value->n);
            self::assertSame($big, gmp_strval($value->n));
            self::assertSame($oracle[0], JsonFacade::bigEcho($value)->toJson());
            self::assertSame('{"n":"' . $big . '"}', json_encode($value, JSON_THROW_ON_ERROR));
        }
        self::assertSame(5, new Big(gmp_init(5))->n);
        self::assertSame(6, new Big('0006')->n);
    }

    public function testWireShapes(): void
    {
        self::assertSame('{"fixed":{"amount":5}}', new ShapeFixed(5)->toJson());
        self::assertSame('{"positional":5}', new ShapePositional(5)->toJson());
        self::assertSame('{"pair":[7,"♥"]}', new ShapePair(7, '♥')->toJson());
        self::assertSame('"none"', new ShapeNone()->toJson());
        self::assertSame('"red"', Color::Red->toJson());
        self::assertSame('"red"', json_encode(Color::Red, JSON_THROW_ON_ERROR));
        self::assertSame(
            '{"label":"x","amount":"18446744073709551615","word":"0","f":"NaN","normal":null,"u":{}}',
            new Data('x', '18446744073709551615', 0, NAN, null, null, null)->toJson(),
        );

        $this->expectException(ValidationError::class);
        ShapeFixed::fromJson('{"fixed":5}');
    }

    public function testJsonTokenizerPreservesStringAndNumberKinds(): void
    {
        $n = '1234567890123456789012345';
        $json = '[{"a":"a\\"' . $n . '","b":' . $n . '},-9223372036854775808,"' . $n . '",0.123456789012345678901]';
        $data = Json::decode($json);
        self::assertIsArray($data);
        self::assertInstanceOf(stdClass::class, $data[0]);
        self::assertSame('a"' . $n, $data[0]->a);
        self::assertInstanceOf(GMP::class, $data[0]->b);
        self::assertSame($n, gmp_strval($data[0]->b));
        self::assertSame(PHP_INT_MIN, $data[1]);
        self::assertSame($n, $data[2]);
        self::assertIsFloat($data[3]);
    }

    private static function canonical(string $json): string
    {
        return Json::encode(self::sortObjects(Json::decode($json)));
    }

    private static function sortObjects(mixed $node): mixed
    {
        if ($node instanceof stdClass) {
            $values = get_object_vars($node);
            ksort($values, SORT_STRING);
            return (object) array_map(self::sortObjects(...), $values);
        }
        return is_array($node) ? array_map(self::sortObjects(...), $node) : $node;
    }
}
