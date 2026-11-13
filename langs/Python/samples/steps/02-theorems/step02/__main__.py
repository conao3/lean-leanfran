from step02.code import m

print([m.sumTo(n) for n in range(6)])
print(m.clamp(0, 10, -5), m.clamp(0, 10, 50), m.clamp(0, 10, 7))
