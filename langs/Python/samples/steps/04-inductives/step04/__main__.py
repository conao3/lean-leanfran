from pydantic import TypeAdapter

from step04.code import m

print([s.value for s in m.Suit if m.Suit.isRed(s)])
E = m.Expr
e = E.add(a=E.num(n=0), b=E.mul(a=E.num(n=1), b=E.neg(a=E.num(n=7))))
print(m.Expr.eval(e))
s = m.Expr.simp(e)
print(TypeAdapter(m.Expr).dump_json(s).decode())
match s:
    case E.neg(a=E.num(n=n)):
        print("negated", n)
