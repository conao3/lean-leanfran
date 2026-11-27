from external import choice as external_choice
from external import settings
from generated import area, choice, report, shapes

point = shapes.Point(x=1, y=2)
template = shapes.Template(seed=shapes.Area_Seed(point=point))
rect = area.place(template.seed)
assert type(rect) is area.Rect
assert type(rect.origin) is shapes.Point
assert report.total([report.Line(label="", origin=point, size=rect)]) == 12
assert area.count(shapes.Counter(value=4)) == shapes.Counter(value=5)
assert area.shapeCount(shapes.Shapes(count=6)) == 6

packet = area.packet(shapes.Status.ready)
assert type(packet) is area.Shapes_Packet_Shapes_Status
assert report.status(packet) is shapes.Status.ready
assert report.boolean(report.Shapes_Packet_Bool(payload=True)) is True

assert type(area.mainFlag(choice.Flag(enabled=True))) is choice.Flag
assert (
    type(report.externalFlag(external_choice.Flag(enabled=True)))
    is external_choice.Flag
)
assert type(report.setting(settings.Level(value=3))) is settings.Level
assert report.grams(area.weigh(7)) == 7
