package consumer

import (
	"errors"
	"math/big"
	"reflect"
	"testing"

	"example.com/embed-fixture/types"
	"github.com/conao3/leanfran-go"
)

func TestModels(t *testing.T) {
	u := uint(32)
	value := types.Record{
		I8: -8, I16: -16, I32: -32, I64: -64, U8: 8, U16: 16, U32: 32, U64: 1 << 63,
		I: -7, U: 1 << 63, Big: big.NewInt(-123), Nat: big.NewInt(123),
		F64: 3.25, F32: 2.5, B: true, S: "猫犬", R: '犬',
		List: []int{-1, 2}, Data: []byte{0, 255}, Opt: &u, Sub: types.Nested{Enabled: true}, Tint: types.Amber,
	}
	got, err := RoundTrip(value)
	if err != nil || !reflect.DeepEqual(got, value) {
		t.Fatalf("round trip returned %+v, %v", got, err)
	}
	for _, color := range []types.Color{types.Amber, types.Blue} {
		if got, err := types.EchoColor(color); err != nil || got != color {
			t.Fatalf("color returned %q, %v", got, err)
		}
	}
	for _, change := range []struct {
		field string
		apply func(*types.Record)
	}{
		{"I_ge", func(r *types.Record) { r.I = -8 }},
		{"I_le", func(r *types.Record) { r.I = 101 }},
		{"Nat", func(r *types.Record) { r.Nat = big.NewInt(-1) }},
		{"S_min_length", func(r *types.Record) { r.S = "猫" }},
		{"List_min_items", func(r *types.Record) { r.List = nil }},
		{"Data_min_items", func(r *types.Record) { r.Data = nil }},
		{"Tint", func(r *types.Record) { r.Tint = "blue" }},
	} {
		invalid := value
		change.apply(&invalid)
		_, err := RoundTrip(invalid)
		var validation *leanfran.ValidationError
		if !errors.As(err, &validation) || len(validation.Issues) != 1 ||
			!reflect.DeepEqual(validation.Issues[0].Path, []any{"value", change.field}) {
			t.Errorf("%s: got %#v (%v)", change.field, validation, err)
		}
	}
	envelope, err := types.Pack(value)
	if err != nil {
		t.Fatal(err)
	}
	desc := envelope.LeanfranDesc().Variants[0].Fields[0].Desc.Ref()
	if desc.Kind != "model" || desc.GoType != "example.com/embed-fixture/types.Record" || len(desc.Variants[0].Fields) != 22 {
		t.Fatalf("model descriptor: %+v", desc)
	}
}
