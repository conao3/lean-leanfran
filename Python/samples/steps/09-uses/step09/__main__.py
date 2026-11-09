from step09.code import report, shapes

S = shapes.Shape
xs = [S.square(side=3), S.rect(w=2, h=7), S.square(side=1)]
print(report.totalArea(xs))
big = report.largest(xs)
print(big, isinstance(big, S))
