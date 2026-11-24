import json
import math

import pydantic
import pytest
from pydantic import TypeAdapter, ValidationError

from leanfran import Err, Lean, LeanType, Local, Ok


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


def test_except(pub):
    assert pub.safeDiv(7, 2) == Ok(value=3)
    assert pub.safeDiv(7, 0) == Err(error=pub.DivError.byZero())
    assert pub.safeDiv(2000, 1) == Err(error=pub.DivError.tooLarge(limit=1000))
    match pub.safeDiv(9, 3):
        case Ok(v):
            assert v == 3
        case _:
            pytest.fail("expected Ok")
    assert pub.orZero(Ok(value=5)) == 5
    assert pub.orZero(Err(error="e")) == 0
    assert pub.orZero({"ok": 6}) == 6
    with pytest.raises(ValidationError, match="non-negative"):
        pub.orZero(Ok(value=-1))
    with pytest.raises(ValidationError):
        pub.orZero(Err(error=1))
    with pytest.raises(ValidationError):
        pub.orZero(5)
    a = pub.Attempt(id=1, result=Err(error="again"))
    assert pub.Attempt.retry(a) == pub.Attempt(id=2, result=Ok(value=pub.Point(x=1, y=0)))
    assert pub.Attempt.retry(pub.Attempt(id=1, result=Err(error="stop"))).result == Err(error="stop")
    assert pub.partitionResults([]) is None
    assert pub.partitionResults([Ok(value=1), Err(error="x"), Ok(value=2)]) == Ok(value=([1, 2], ["x"]))


def test_except_json(pub):
    r = pub.safeDiv(7, 2)
    assert r.model_dump_json() == '{"ok":3}'
    assert pub.safeDiv(7, 0).model_dump_json() == '{"error":"byZero"}'
    assert pub.safeDiv(2000, 1).model_dump_json() == '{"error":{"tooLarge":{"limit":1000}}}'
    ta = TypeAdapter(Ok[pub.Point] | Err[str])
    assert ta.validate_json('{"ok": {"x": 1, "y": -1}}') == Ok(value=pub.Point(x=1, y=-1))
    assert ta.validate_json('{"error": "e"}') == Err(error="e")
    with pytest.raises(ValidationError):
        ta.validate_json('{"ok": 1, "error": "e"}')
    a = pub.Attempt.model_validate_json('{"id": 1, "result": {"error": "again"}}')
    assert json.loads(pub.Attempt.retry(a).model_dump_json()) == {"id": 2, "result": {"ok": {"x": 1, "y": 0}}}
    schema = pub.Attempt.model_json_schema()
    assert {"$ref": "#/$defs/Err_str_"} in schema["properties"]["result"]["anyOf"]


def test_handles(pub):
    xs = pub.squares.lean.params["xs"].new([1, -2, 3])
    assert isinstance(xs, Lean)
    ys = pub.squares.lean(xs)
    assert ys.get() == [1, 4, 9]
    assert xs.get() == [1, -2, 3]
    assert pub.squares.lean(ys).get() == [1, 16, 81]
    assert pub.squares.lean(ys).get() == [1, 16, 81]
    assert ys.get() == [1, 4, 9]
    assert pub.squares.lean([2]).get() == [4]
    assert repr(ys) == "Lean([1, 4, 9])"
    assert pub.answer.lean().get() == 42
    assert pub.answer() == 42
    assert pub.mix.lean(255, 65535, 1, 2, 3).get() == 255 + 65535 + 6
    assert pub.safeDiv.lean(7, 2).get() == Ok(value=3)
    assert pub.orZero.lean(pub.orZero.lean.params["r"].new(Ok(value=9))).get() == 9
    assert pub.safeDiv.lean(7, 2).type.new(Ok(value=9)).get() == Ok(value=9)


def test_handles_keep_their_value(pub):
    tree = pub.Tree.ofList.lean([2, 1, 3])
    bigger = pub.Tree.insert.lean(tree, 0)
    assert pub.Tree.toList.lean(tree).get() == [1, 2, 3]
    assert pub.Tree.toList.lean(bigger).get() == [0, 1, 2, 3]
    assert pub.Tree.insert.lean(tree, 4).get() == pub.Tree.insert(tree.get(), 4)
    sample = pub.Sample.bump.lean(pub.Sample(name="s", count=1, weight=0.5, flag=False, tags=["t"]))
    again = pub.Sample.bump.lean(sample)
    assert sample.get().count == 2
    assert again.get().count == 3
    assert pub.Sample.describe.lean(sample).get() == pub.Sample.describe(sample.get())


def test_handle_types(pub):
    xs_type = pub.squares.lean.params["xs"]
    assert isinstance(xs_type, LeanType)
    assert xs_type == pub.squares.lean.result
    assert xs_type != pub.sumList.lean.params["xs"]
    assert pub.squares.lean(xs_type.new([3])).type == xs_type
    with pytest.raises(ValidationError, match="expected a handle of list\\[Nat\\]"):
        pub.sumList.lean(xs_type.new([1]))
    with pytest.raises(ValidationError):
        xs_type.new(["a"])
    with pytest.raises(ValidationError, match="non-negative"):
        pub.double.lean(-1)
    assert not hasattr(pub.readBack, "lean")


def test_local_handles(pub):
    xs = pub.squares.local.params["xs"].new_local([1, -2, 3])
    assert isinstance(xs, Local)
    ys = pub.squares.local(xs)
    assert ys.get() == [1, 4, 9]
    assert xs.get() == [1, -2, 3]
    zs = pub.squares.local(ys.take())
    assert zs.get() == [1, 16, 81]
    assert repr(ys) == "Local(<taken>)"
    with pytest.raises(ValueError, match="take"):
        ys.get()
    with pytest.raises(ValueError, match="take"):
        pub.squares.local(ys)
    assert pub.squares.local([2]).get() == [4]
    assert pub.answer.local().get() == 42
    assert pub.mix.local(255, 65535, 1, 2, 3).get() == 255 + 65535 + 6
    assert repr(zs) == "Local([1, 16, 81])"
    with pytest.raises(ValidationError, match="expected a handle of list\\[Nat\\]"):
        pub.sumList.local(zs)
    assert not hasattr(pub.readBack, "local")


def test_local_handles_update_in_place_only_when_taken(pub):
    tree = pub.Tree.ofList.local([2, 1, 3])
    kept = pub.Tree.insert.local(tree, 0)
    assert pub.Tree.toList.local(tree).get() == [1, 2, 3]
    assert pub.Tree.toList.local(kept).get() == [0, 1, 2, 3]
    moved = pub.Tree.insert.local(kept.take(), 5)
    assert pub.Tree.toList.local(moved).get() == [0, 1, 2, 3, 5]
    assert pub.Tree.toList.local(tree).get() == [1, 2, 3]
    assert pub.Tree.toList.local(tree.take()).get() == [1, 2, 3]
    sample = pub.Sample.bump.local(pub.Sample(name="s", count=1, weight=0.5, flag=False, tags=["t"]))
    again = pub.Sample.bump.local(sample)
    third = pub.Sample.bump.local(again.take())
    assert (sample.get().count, third.get().count) == (2, 4)


def test_local_and_shared_handles_mix(pub):
    local = pub.squares.local([1, 2])
    shared = local.share()
    assert isinstance(shared, Lean)
    assert pub.squares.local(shared).get() == [1, 16]
    assert pub.squares.local(local.take()).get() == [1, 16]
    assert shared.get() == [1, 4]
    other = pub.squares.local([3])
    assert pub.squares.lean(other).get() == [81]
    assert other.get() == [9]
    assert pub.squares.local(other.take()).get() == [81]
    assert pub.squares.lean(pub.squares.local([2]).take()).get() == [16]


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
    with pytest.raises(ValidationError, match="less than or equal to 100"):
        pub.Discount.percent(p=150)
    with pytest.raises(ValidationError, match="p ≤ 100"):
        pub.Discount.apply(pub.Discount.percent.model_construct(p=150), 1)
    assert pub.small(10) == 20
    with pytest.raises(ValidationError, match="val < 100"):
        pub.small(100)
    with pytest.raises(ValidationError, match="less than 100"):
        TypeAdapter(pub._Subtype0).validate_python(100)
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


def test_bounds_in_json_schema(pub):
    percent = pub.Discount.percent.model_json_schema()
    assert percent["properties"]["p"]["maximum"] == 100
    assert TypeAdapter(pub._Subtype0).json_schema()["exclusiveMaximum"] == 100


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


def test_io_files(pub, tmp_path):
    f = tmp_path / "a.txt"
    f.write_text("héllo\n")
    assert pub.readBack(str(f)) == "héllo\n"
    with pytest.raises(OSError, match="no such file"):
        pub.readBack(str(tmp_path / "missing"))
