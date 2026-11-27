package main

import (
	"math/big"

	external "example.com/shapes/external/choice"
	"example.com/shapes/external/settings"
	"example.com/shapes/generated/area"
	"example.com/shapes/generated/choice"
	"example.com/shapes/generated/report"
	"example.com/shapes/generated/shapes"
)

func main() {
	point := shapes.Point{X: big.NewInt(1), Y: big.NewInt(2)}
	template := shapes.Template{Seed: shapes.AreaSeed{Point: point}}
	rect, _ := area.Place(template.Seed)
	_, _ = report.Total([]report.Line{{Origin: point, Size: rect}})
	_ = area.Count(shapes.Counter{Value: 4})

	var status shapes.Status = report.Status(area.Packet(shapes.StatusReady()))
	_ = status
	_ = report.Boolean(report.ShapesPacketBool{Payload: true})
	_ = report.Grams(area.Weigh(7))

	var mainFlag choice.Flag = area.MainFlag(choice.Flag{Enabled: true})
	var externalFlag external.Flag = report.ExternalFlag(external.Flag{Enabled: true})
	var setting settings.Level = report.Setting(settings.Level{Value: 3})
	_, _, _ = mainFlag, externalFlag, setting
}
