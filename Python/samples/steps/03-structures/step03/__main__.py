from pydantic import ValidationError

from step03.code import m

p = m.Point.add(m.Point(x=1, y=-2), m.Point(x=3, y=5))
print(p, m.Point.norm1(p))
r = m.Range.shift(m.Range(lo=1, hi=4), 10)
print(r, m.Range.width(r))
try:
    m.Range(lo=5, hi=1)
except ValidationError as e:
    print("rejected:", e.errors()[0]["msg"])
