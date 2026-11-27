import assert from "node:assert/strict"
import * as externalChoice from "./external/Choice.ts"
import * as settings from "./external/Settings.ts"
import * as choice from "./generated/Choice.ts"
import * as report from "./generated/Report.ts"
import * as area from "./generated/Shapes/Area.ts"
import * as shapes from "./generated/models/Shapes.ts"

const point: shapes.Point = { x: 1n, y: 2n }
const seed: shapes.Area_Seed = { point }
const rect: area.Rect = area.place(seed)
assert.deepEqual(rect.origin, point)
assert.equal(report.total([{ label: "", origin: point, size: rect }]), 12n)
assert.deepEqual(area.count({ value: 4n }), { value: 5n })
assert.equal(area.shapeCount({ count: 6n }), 6n)
assert.ok(!("Rect" in report))
assert.ok(!("Shapes_Point" in area))
assert.ok(!("Shapes_Point" in report))

const packet: area.Shapes_PacketShapesStatus = area.packet("ready")
assert.equal(report.status(packet), "ready")
assert.equal(area.Shapes_PacketShapesStatus.desc.kind, "struct")
assert.ok(!("Shapes_PacketShapesStatus" in report))
assert.equal(report.boolean({ payload: true }), true)
assert.equal(report.grams(area.weigh(7n)), 7n)
assert.ok(!("Loose_Weight" in report))

assert.notEqual(choice.Flag, externalChoice.Flag)
assert.deepEqual(area.mainFlag({ enabled: true }), { enabled: true })
assert.deepEqual(report.externalFlag({ enabled: true }), { enabled: true })
assert.deepEqual(report.setting({ value: 3n }), { value: 3n })
assert.equal(settings.Level.desc.kind, "struct")
assert.ok(!("Choice_Flag" in report))
assert.ok(!("Settings_Level" in report))
