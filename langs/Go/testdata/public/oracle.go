package main

import (
	"encoding/json"
	"fmt"
	"math/big"
	"os"

	"github.com/conao3/leanfran-go/test-out/_generated/public/allocations"
	values "github.com/conao3/leanfran-go/test-out/_generated/public/json"
	"github.com/conao3/leanfran-go/test-out/_generated/public/public"
)

func show(value any, err error) {
	if err != nil {
		panic(err)
	}
	data, err := json.Marshal(value)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(data))
}

func roundTrip[T any](items []T, err error, decode func([]byte) (T, error)) {
	if err != nil {
		panic(err)
	}
	for _, item := range items {
		data, err := json.Marshal(item)
		if err != nil {
			panic(err)
		}
		back, err := decode(data)
		show(back, err)
	}
}

func decode[T any](data []byte) (T, error) {
	var value T
	err := json.Unmarshal(data, &value)
	return value, err
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "schema" {
		schemas()
		return
	}
	sum, err := public.Total([]*big.Int{big.NewInt(1200), big.NewInt(800)}, public.DiscountPercent{P: big.NewInt(10)})
	show(sum, err)
	bigValue, err := values.Big_2()
	roundTrip([]values.Big{bigValue}, err, decode[values.Big])
	data, err := values.Data_2()
	roundTrip(data, err, decode[values.Data])
	shapes, err := values.Shapes()
	roundTrip(shapes, err, values.UnmarshalShape)
	colors, err := values.Colors()
	roundTrip(colors, err, decode[values.Color])
	trees, err := values.Trees()
	roundTrip(trees, err, values.UnmarshalTree)
	for _, n := range []string{"0", "9223372036854775807", "9223372036854775808", "18446744073709551617"} {
		value, _ := new(big.Int).SetString(n, 10)
		show(allocations.NatEcho(value))
	}
	for _, n := range []string{"-9223372036854775809", "-9223372036854775808", "-1", "0", "9223372036854775807", "9223372036854775808"} {
		value, _ := new(big.Int).SetString(n, 10)
		show(allocations.IntEcho(value))
	}
}

type schemer interface {
	JSONSchema(string) (map[string]any, error)
}

func schemas() {
	types := []struct {
		name  string
		value schemer
	}{
		{"Big", values.Big{}},
		{"Color", values.ColorRed},
		{"Data", values.Data{}},
		{"Discount", public.DiscountNone{}},
		{"Packed", public.Packed{}},
		{"Range", public.Range{}},
		{"Shape", values.ShapeNone{}},
		{"Tree", values.TreeLeaf{}},
	}
	var rows []any
	for _, typ := range types {
		for _, target := range []string{"draft-2020-12", "draft-07", "openapi-3.0"} {
			s, err := typ.value.JSONSchema(target)
			if err != nil {
				panic(err)
			}
			rows = append(rows, map[string]any{"type": typ.name, "target": target, "schema": s})
		}
	}
	show(rows, nil)
}
