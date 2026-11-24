package public_test

import (
	"encoding/json"
	"errors"
	"math"
	"math/big"
	"reflect"
	"strings"
	"sync"
	"testing"

	"github.com/conao3/leanfran-go"
	"github.com/conao3/leanfran-go/rt"
	"github.com/conao3/leanfran-go/test-out/_generated/public/client"
	values "github.com/conao3/leanfran-go/test-out/_generated/public/json"
	"github.com/conao3/leanfran-go/test-out/_generated/public/public"
)

func TestScalarAndContainerRoundTrip(t *testing.T) {
	n := new(big.Int).Lsh(big.NewInt(1), 115)
	p := public.Packed{
		Flag: true, U8: 234, U16: 567, U32: 1 << 31, U64: math.MaxUint64, Usize: 42,
		I8: -123, I16: -456, I32: -1234567, I64: -1 << 63, Isize: -42,
		F64: 123.125, F32: -0.625, C: '日', S: "é日", N: n, I: new(big.Int).Neg(n),
	}
	got, err := public.PackedEcho(p)
	if err != nil || !reflect.DeepEqual(got, p) {
		t.Fatalf("round trip: %+v, %v", got, err)
	}
	read, err := public.PackedRead(p)
	if err != nil || read != 41 {
		t.Fatalf("mixed layout: %d, %v", read, err)
	}
	bigger := public.Bigger{
		Flag: p.Flag, U8: p.U8, U16: p.U16, U32: p.U32, U64: p.U64, Usize: p.Usize, I8: p.I8,
		I16: p.I16, I32: p.I32, I64: p.I64, Isize: p.Isize, F64: p.F64, F32: p.F32, C: p.C,
		S: p.S, N: p.N, I: p.I, Extra: big.NewInt(67),
	}
	bigGot, err := public.BiggerEcho(bigger)
	if err != nil || !reflect.DeepEqual(bigGot, bigger) {
		t.Fatalf("flattened round trip: %+v, %v", bigGot, err)
	}
	n.SetInt64(10)
	if got.N.BitLen() != 116 {
		t.Fatal("returned Nat shares storage with the input")
	}
	public.UnitEcho(struct{}{})
	data := []byte{0, 12, 255}
	bytes := public.ByteEcho(data)
	data[2] = 0
	if len(bytes) != 3 || bytes[2] != 255 {
		t.Fatalf("ByteArray: %v", bytes)
	}
	x := big.NewInt(42)
	some := &x
	failure := "bad"
	choices := public.Choices{
		Fit: math.MaxUint64, Large: new(big.Int).Lsh(big.NewInt(1), 79),
		Pair:   leanfran.Pair[string, bool]{Fst: "yes", Snd: true},
		Result: leanfran.Except[string, *big.Int]{Error: &failure}, Maybe: &some,
	}
	choiceGot, err := public.ChoicesEcho(choices)
	if err != nil || !reflect.DeepEqual(choiceGot, choices) {
		t.Fatalf("choices: %+v, %v", choiceGot, err)
	}
	generic := public.GenericNat{Item: big.NewInt(19)}
	genericGot, err := public.GenericEcho(generic)
	if err != nil || genericGot.Item.Cmp(generic.Item) != 0 {
		t.Fatalf("monomorphized structure: %+v, %v", genericGot, err)
	}
	a, err := public.LowerCase(big.NewInt(7))
	if err != nil || a.Int64() != 7 {
		t.Fatal(a, err)
	}
	b, err := public.LowerCase_2(big.NewInt(7))
	if err != nil || b.Int64() != 8 {
		t.Fatal(b, err)
	}
	keywordFields := public.String{Type: big.NewInt(1), Func: big.NewInt(2), Validate_2: big.NewInt(3)}
	if err := keywordFields.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestValidation(t *testing.T) {
	r := public.Range{Lo: big.NewInt(5), Hi: big.NewInt(3)}
	_, err := public.NewRange(r.Lo, r.Hi)
	checkIssue(t, err, "Range.ok: lo ≤ hi", []any{"Range", "ok"})
	_, err = public.ArrEcho([]public.Range{r})
	checkIssue(t, err, "r.0.ok: lo ≤ hi", []any{"r", 0, "ok"})
	_, err = public.NewDiscountPercent(big.NewInt(101))
	checkIssue(t, err, "Discount.percent.h: p ≤ 100", []any{"Discount", "percent", "h"})
	_, err = public.NewSmall(big.NewInt(10))
	checkIssue(t, err, "Small.property", []any{"Small", "property"})
	_, err = public.AnonymousEcho(big.NewInt(10))
	checkIssue(t, err, "n.property", []any{"n", "property"})
	_, err = public.Total(nil, (*public.DiscountNone)(nil))
	checkIssue(t, err, "d: expected Discount", []any{"d"})
	var v public.Range
	err = v.Validate()
	checkIssue(t, err, "Range.lo", []any{"Range", "lo"})
	var validation *leanfran.ValidationError
	if !errors.As(err, &validation) || len(validation.Issues) != 2 {
		t.Fatalf("expected two issues: %#v", validation)
	}
	err = json.Unmarshal([]byte(`{"lo":5,"hi":3}`), &v)
	checkIssue(t, err, "Range.ok: lo ≤ hi", []any{"Range", "ok"})
	if v.Lo != nil {
		t.Fatal("UnmarshalJSON modified the receiver after a validation error")
	}
}

func checkIssue(t *testing.T, err error, message string, path []any) {
	t.Helper()
	var validation *leanfran.ValidationError
	if !errors.As(err, &validation) || len(validation.Issues) == 0 ||
		!strings.HasPrefix(err.Error(), message) || !reflect.DeepEqual(validation.Issues[0].Path, path) {
		t.Fatalf("expected %s at %v, got %v (%#v)", message, path, err, validation)
	}
}

func TestErrors(t *testing.T) {
	_, err := public.ExceptEcho(false)
	var resultError *leanfran.ExceptError[uint32]
	if !errors.As(err, &resultError) || resultError.Value != 17 {
		t.Fatalf("Except: %v", err)
	}
	got, err := public.ExceptEcho(true)
	if err != nil || got != "success" {
		t.Fatal(got, err)
	}
	_, err = public.IoFail(struct{}{})
	var ioError *leanfran.IOError
	if !errors.As(err, &ioError) || ioError.Error() != "nope" {
		t.Fatalf("IO error: %v", err)
	}
	func() {
		defer func() {
			if value := recover(); value == nil {
				t.Fatal("unreachable returned")
			} else if _, ok := value.(*rt.InternalPanic); !ok {
				t.Fatalf("unreachable panicked with %T: %v", value, value)
			}
		}()
		_, _ = public.ExecuteUnreachable(big.NewInt(1))
	}()
	value, err := public.IoEcho("Lean")
	if err != nil || value != "Lean!" {
		t.Fatal(value, err)
	}
}

func TestForeignTypes(t *testing.T) {
	r := public.Range{Lo: big.NewInt(2), Hi: big.NewInt(5)}
	width, err := client.Width(r)
	if err != nil || width.Int64() != 3 {
		t.Fatal(width, err)
	}
	d := public.DiscountPercent{P: big.NewInt(29)}
	got, err := client.Echo(d)
	if err != nil || !reflect.DeepEqual(got, d) {
		t.Fatal(got, err)
	}
	r.Hi.SetInt64(1)
	_, err = client.Width(r)
	checkIssue(t, err, "r.ok: lo ≤ hi", []any{"r", "ok"})
}

func TestConcurrent(t *testing.T) {
	prices := []*big.Int{big.NewInt(1200), big.NewInt(800)}
	discount := public.DiscountPercent{P: big.NewInt(10)}
	var wg sync.WaitGroup
	for range 8 {
		wg.Go(func() {
			for range 100 {
				s, err := public.Total(prices, discount)
				if err != nil || s.Int64() != 1800 {
					t.Error(s, err)
				}
			}
		})
	}
	wg.Wait()
}

func TestListAndAllocations(t *testing.T) {
	items := make([]uint32, 1_000_000)
	for i := range items {
		items[i] = uint32(i)
	}
	got := public.ListEcho(items)
	if !reflect.DeepEqual(got, items) {
		t.Fatal("million-element round trip failed")
	}
	if allocs := testing.AllocsPerRun(100, func() {
		if got := public.UintEcho(math.MaxUint64); got != math.MaxUint64 {
			t.Fatal(got)
		}
	}); allocs != 0 {
		t.Fatalf("UInt64 call allocated %v times", allocs)
	}
}

func TestPublicSignatures(t *testing.T) {
	reply := public.ReplyFor(math.MaxUint64)
	if reply.V != math.MaxUint64 {
		t.Fatal(reply)
	}
	checkJSON := func(value any, expected string) {
		t.Helper()
		payload, err := json.Marshal(value)
		if err != nil || string(payload) != expected {
			t.Fatalf("JSON = %s, %v, want %s", payload, err, expected)
		}
		dst := reflect.New(reflect.TypeOf(value))
		if err := json.Unmarshal(payload, dst.Interface()); err != nil || dst.Elem().Interface() != value {
			t.Fatalf("round trip: %v, %v", dst.Elem(), err)
		}
	}
	checkJSON(reply, `{"value":{"v":"18446744073709551615"}}`)
	checkJSON(public.GivenFor(9), `{"only":"9"}`)
	marker := public.MarkerFor()
	checkJSON(marker, `"only"`)
	markerSchema, err := marker.JSONSchema("draft-2020-12")
	if err != nil || markerSchema["type"] != "string" || !reflect.DeepEqual(markerSchema["enum"], []string{"only"}) {
		t.Fatalf("marker schema = %v, %v", markerSchema, err)
	}
	checkJSON(values.ColorBlue(), `"blue"`)

	switch values.ColorRed() {
	case values.ColorRed():
	default:
		t.Fatal("red constructor did not match")
	}
	if (values.Color{}) != values.ColorRed() {
		t.Fatal("zero color did not select the first constructor")
	}
	color := values.ColorBlue()
	if err := json.Unmarshal([]byte(`"pow"`), &color); err == nil || color != values.ColorBlue() {
		t.Fatalf("invalid color: %v, %v", color, err)
	}

	raw := public.NewValue_UInt64(9)
	public.Handle_UnitEcho(public.NewValue_Unit(struct{}{}).Take())
	leanReply := public.Handle_ReplyFor(raw.Take())
	defer leanReply.Close()
	if got := public.ReadValue_Reply(leanReply); got.V != 9 {
		t.Fatal(got)
	}
	record, err := public.NewRecordValue(9)
	if err != nil {
		t.Fatal(err)
	}
	input, err := public.NewValue_Record(record)
	if err != nil {
		t.Fatal(err)
	}
	output := public.Handle_RecordValue_2(input.Take())
	defer output.Close()
	if got := public.ReadValue_Record(output); got != record {
		t.Fatal(got)
	}
}
