import json
import math

import pydantic
import pytest
from pydantic import TypeAdapter, ValidationError


def test_scalars(pub):
    assert pub.double(21) == 42
    assert pub.double(2**80) == 2**81
    assert pub.isEven(10) is True
    assert pub.negate(-5) == 5
    assert pub.mix(255, 65535, 1, 2, 3) == 255 + 65535 + 6
    assert pub.signed(-1, -2, -3, -4) == -10
    assert pub.halve(3.0) == 1.5
    assert pub.nextChar("a") == "b"
    assert pub.greet("λ") == "こんにちは, λ! (1)"
    assert pub.unit(None) is None
    assert pub.answer() == 42
    assert pub.big() == 2**100


def test_containers(pub):
    assert pub.sumList([1, 2, 3]) == 6
    assert pub.squares([-2, 3]) == [4, 9]
    assert pub.firstEven_q([1, 3, 4]) == 4
    assert pub.firstEven_q([1]) is None
    assert pub.swap((1, "a")) == ("a", 1)
    assert pub.lastOf(9) == 9


def test_argument_errors(pub):
    with pytest.raises(ValidationError, match="non-negative"):
        pub.double(-1)
    with pytest.raises(ValidationError):
        pub.double(True)
    with pytest.raises(ValidationError):
        pub.mix(256, 0, 0, 0, 0)
    with pytest.raises(ValidationError):
        pub.lastOf(10)
    with pytest.raises(ValidationError) as e:
        pub.sumList([1, -2])
    assert e.value.errors()[0]["loc"] == ("xs", 1)


def test_structures(pub):
    p = pub.Point(x=1, y=-2)
    assert pub.Point.add(p, pub.Point(x=2, y=3)) == pub.Point(x=3, y=1)
    s = pub.Sample(name="s", count=4294967295, weight=0.5, flag=True, tags=["a", "b"])
    assert pub.Sample.describe(s) == "s:4294967295:0.500000:true:[a, b]"
    b = pub.Sample.bump(s)
    assert (b.count, b.flag, b.tags) == (0, False, ["a", "b"])
    assert pub.Meters.twice(pub.Meters(val=21)) == pub.Meters(val=42)
    with pytest.raises(ValidationError):
        pub.Point(x=-1, y=0)
    with pytest.raises(ValidationError):
        pub.Point(x="1", y=0)
    with pytest.raises(pydantic.ValidationError):
        p.x = 3


def test_enums_and_inductives(pub):
    assert pub.Color.next(pub.Color.blue) is pub.Color.red
    assert pub.Shape.area(pub.Shape.circle(radius=2)) == 12
    assert pub.Shape.area(pub.Shape.dot()) == 0
    r = pub.Shape.scale(2, pub.Shape.rect(width=1, height=3))
    assert isinstance(r, pub.Shape)
    match r:
        case pub.Shape.rect(width=w, height=h):
            assert (w, h) == (2, 6)
        case _:
            pytest.fail("not a rect")
    t = pub.Tree.ofList([5, 2, 8, 1])
    assert pub.Tree.toList(t) == [1, 2, 5, 8]
    assert pub.Token.weight(pub.Token.pair(a0=3, a1="ab")) == 5


def test_invariants(pub):
    assert pub.Range.width(pub.Range(lo=1, hi=4)) == 3
    with pytest.raises(ValidationError, match="lo ≤ hi"):
        pub.Range(lo=5, hi=1)
    bad = pub.Range.model_construct(lo=5, hi=1)
    with pytest.raises(ValidationError, match="lo ≤ hi"):
        pub.Range.width(bad)
    assert pub.Range.widen(pub.Range(lo=1, hi=2), 3) == pub.Range(lo=1, hi=5)
    assert pub.Discount.apply(pub.Discount.percent(p=10), 200) == 180
    with pytest.raises(ValidationError, match="p ≤ 100"):
        pub.Discount.percent(p=150)
    assert pub.small(10) == 20
    with pytest.raises(ValidationError, match="val < 100"):
        pub.small(100)
    with pytest.raises(ValidationError):
        TypeAdapter(pub._Subtype0).validate_python(100)


def test_json_matches_lean(pub):
    shape = TypeAdapter(pub.Shape)
    assert shape.dump_json(pub.Shape.rect(width=1, height=2)) == b'{"rect":{"width":1,"height":2}}'
    assert shape.dump_json(pub.Shape.dot()) == b'"dot"'
    assert shape.validate_json('{"circle": {"radius": 3}}') == pub.Shape.circle(radius=3)
    assert shape.validate_json('"dot"') == pub.Shape.dot()
    token = TypeAdapter(pub.Token)
    assert json.loads(token.dump_json(pub.Token.pair(a0=1, a1="x"))) == {"pair": [1, "x"]}
    assert json.loads(token.dump_json(pub.Token.num(a0=7))) == {"num": 7}
    assert token.validate_json('{"pair": [1, "x"]}') == pub.Token.pair(a0=1, a1="x")
    discount = TypeAdapter(pub.Discount)
    with pytest.raises(ValidationError):
        discount.validate_json('{"percent": {"p": 150}}')
    with pytest.raises(ValidationError):
        discount.validate_json('{"percent": {"p": "10"}}')
    assert pub.Point.model_validate_json('{"x": 1, "y": -1}') == pub.Point(x=1, y=-1)
    tree = pub.Tree.ofList([2, 1])
    assert json.loads(TypeAdapter(pub.Tree).dump_json(tree)) == {
        "node": {"l": {"node": {"l": "leaf", "v": 1, "r": "leaf"}}, "v": 2, "r": "leaf"}
    }
    assert TypeAdapter(pub.Tree).validate_json(TypeAdapter(pub.Tree).dump_json(tree)) == tree


def test_json_schema(pub):
    schema = TypeAdapter(pub.Shape).json_schema()
    tags = [v.get("const") or next(iter(v["properties"])) for v in schema["oneOf"]]
    assert tags == ["circle", "rect", "dot"]
    assert pub.Point.model_json_schema()["properties"]["x"]["minimum"] == 0


def test_io(pub):
    assert pub.ioEcho("hi") == "hi!"
    with pytest.raises(OSError, match="nope"):
        pub.failing(None)


def test_floats(pub):
    assert math.isinf(pub.halve(math.inf))
