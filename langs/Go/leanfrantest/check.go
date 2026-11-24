package leanfrantest

import (
	"fmt"
	"math"
	"math/rand/v2"
	"reflect"
	"slices"
	"testing"

	"github.com/conao3/leanfran-go"
	"github.com/conao3/leanfran-go/schema"
)

type Model struct {
	Name     string
	Function any
	Requires any
	Refines  any
	Ensures  map[string]any
}

type settings struct {
	runs int
	seed uint64
}

type Option func(*settings)

func Runs(n int) Option    { return func(s *settings) { s.runs = n } }
func Seed(n uint64) Option { return func(s *settings) { s.seed = n } }

func Check(t *testing.T, m Model, opts ...Option) {
	t.Helper()
	cfg := settings{runs: 200, seed: 1}
	for _, opt := range opts {
		opt(&cfg)
	}
	if cfg.runs < 1 {
		t.Fatalf("%s: runs must be positive", m.Name)
	}
	fn := reflect.ValueOf(m.Function)
	if fn.Kind() != reflect.Func || fn.IsNil() || fn.Type().IsVariadic() {
		t.Fatalf("%s: model must be a non-variadic function", m.Name)
	}
	if m.Refines == nil && len(m.Ensures) == 0 {
		t.Fatalf("%s: model needs a refines or ensures function", m.Name)
	}
	names := make([]string, 0, len(m.Ensures))
	for label := range m.Ensures {
		names = append(names, label)
	}
	slices.Sort(names)
	rng := rand.New(rand.NewPCG(cfg.seed, 0))
	accepted := 0
	signature := fn.Type()
	for trial := 0; trial/cfg.runs < 100 && accepted < cfg.runs; trial++ {
		input := make([]reflect.Value, signature.NumIn())
		for i := range input {
			v, err := sample(signature.In(i), rng, trial, 0)
			if err != nil {
				t.Fatalf("%s: argument %d: %v", m.Name, i+1, err)
			}
			input[i] = v
		}
		failure, discard := compare(m, fn, input, names)
		if discard {
			continue
		}
		if failure != "" {
			t.Errorf("%s: %s (seed=%d, input=%#v)", m.Name, failure, cfg.seed, values(input))
			return
		}
		accepted++
	}
	if accepted != cfg.runs {
		t.Errorf("%s: requires accepted %d of %d requested inputs (seed=%d)", m.Name, accepted, cfg.runs, cfg.seed)
	}
}

func values(args []reflect.Value) []any {
	out := make([]any, len(args))
	for i, arg := range args {
		out[i] = arg.Interface()
	}
	return out
}

var errorType = reflect.TypeFor[error]()

func invoke(callable any, args []reflect.Value) (result []reflect.Value, err error) {
	f := reflect.ValueOf(callable)
	if f.Kind() != reflect.Func || f.IsNil() || f.Type().NumIn() != len(args) || f.Type().IsVariadic() {
		return nil, fmt.Errorf("oracle must be a non-variadic function taking %d values", len(args))
	}
	defer func() {
		if e := recover(); e != nil {
			err = fmt.Errorf("panic: %v", e)
		}
	}()
	in := make([]reflect.Value, len(args))
	for i, arg := range args {
		want := f.Type().In(i)
		adapted, ok := adapt(arg, want)
		if !ok {
			return nil, fmt.Errorf("argument %d has type %s, oracle expects %s", i+1, arg.Type(), want)
		}
		in[i] = adapted
	}
	result = f.Call(in)
	if n := len(result); n != 0 && result[n-1].Type() == errorType {
		e := result[n-1]
		result = result[:n-1]
		if !e.IsNil() {
			return result, e.Interface().(error)
		}
	}
	return result, nil
}

func adapt(v reflect.Value, want reflect.Type) (reflect.Value, bool) {
	switch {
	case v.Type().AssignableTo(want):
		return v, true
	case sameWidth(v.Type(), want) && v.CanConvert(want):
		return v.Convert(want), true
	case v.Kind() == reflect.Slice && want.Kind() == reflect.Slice:
		out := reflect.MakeSlice(want, v.Len(), v.Len())
		for i := 0; i < v.Len(); i++ {
			x, ok := adapt(v.Index(i), want.Elem())
			if !ok {
				return reflect.Value{}, false
			}
			out.Index(i).Set(x)
		}
		return out, true
	default:
		return reflect.Value{}, false
	}
}

func predicate(oracle any, inputs []reflect.Value) (bool, error) {
	out, err := invoke(oracle, inputs)
	if err != nil {
		return false, err
	}
	if len(out) != 1 || out[0].Kind() != reflect.Bool {
		return false, fmt.Errorf("predicate must return bool or (bool, error)")
	}
	return out[0].Bool(), nil
}

func compare(m Model, fn reflect.Value, inputs []reflect.Value, labels []string) (string, bool) {
	if m.Requires != nil {
		ok, err := predicate(m.Requires, inputs)
		if err != nil {
			if _, invalid := err.(*leanfran.ValidationError); invalid {
				return "", true
			}
			return fmt.Sprintf("requires: %v", err), false
		}
		if !ok {
			return "", true
		}
	}
	var expected []reflect.Value
	if m.Refines != nil {
		result, err := invoke(m.Refines, inputs)
		if err != nil {
			if _, invalid := err.(*leanfran.ValidationError); invalid {
				return "", true
			}
			return fmt.Sprintf("refines oracle: %v", err), false
		}
		expected = result
	}
	actual, err := invoke(fn.Interface(), inputs)
	if err != nil {
		return fmt.Sprintf("implementation: %v", err), false
	}
	if m.Refines != nil && !equalResults(actual, expected) {
		return fmt.Sprintf("refines: got %#v, want %#v", values(actual), values(expected)), false
	}
	for _, label := range labels {
		oracle := m.Ensures[label]
		args := slices.Concat(inputs, actual)
		if len(actual) > 1 {
			f := reflect.TypeOf(oracle)
			if f != nil && f.Kind() == reflect.Func && f.NumIn() == len(inputs)+1 {
				pair, ok := makeProduct(f.In(len(inputs)), actual)
				if ok {
					args = append(slices.Clone(inputs), pair)
				}
			}
		}
		if len(actual) == 0 {
			args = append(slices.Clone(inputs), reflect.ValueOf(struct{}{}))
		}
		ok, err := predicate(oracle, args)
		if err != nil {
			return fmt.Sprintf("%s oracle: %v", label, err), false
		}
		if !ok {
			return fmt.Sprintf("%s: false for result %#v", label, values(actual)), false
		}
	}
	return "", false
}

func equalResults(actual, expected []reflect.Value) bool {
	if len(expected) == 1 && len(actual) > 1 {
		pair, ok := makeProduct(expected[0].Type(), actual)
		return ok && equal(pair, expected[0])
	}
	if len(actual) != len(expected) {
		return false
	}
	for i := range actual {
		if !equal(actual[i], expected[i]) {
			return false
		}
	}
	return true
}

func makeProduct(typ reflect.Type, terms []reflect.Value) (reflect.Value, bool) {
	if len(terms) == 1 {
		arg := terms[0]
		if arg.Type() == typ {
			return arg, true
		}
		if sameWidth(typ, arg.Type()) && arg.CanConvert(typ) {
			return arg.Convert(typ), true
		}
		return reflect.Value{}, false
	}
	if len(terms) < 2 || typ.Kind() != reflect.Struct {
		return reflect.Value{}, false
	}
	prod := reflect.New(typ).Elem()
	a, b := prod.FieldByName("Fst"), prod.FieldByName("Snd")
	if !a.IsValid() || !b.IsValid() || !a.CanSet() || !b.CanSet() || prod.NumField() != 2 {
		return reflect.Value{}, false
	}
	x, ok := makeProduct(a.Type(), terms[:1])
	if !ok {
		return reflect.Value{}, false
	}
	y, ok := makeProduct(b.Type(), terms[1:])
	if !ok {
		return reflect.Value{}, false
	}
	a.Set(x)
	b.Set(y)
	return prod, true
}

func sameWidth(a, b reflect.Type) bool {
	x, y := a.Kind(), b.Kind()
	if x == y && x >= reflect.Bool && x <= reflect.Float64 || x == reflect.String && y == x {
		return true
	}
	return x == reflect.Int && y == reflect.Int64 || x == reflect.Int64 && y == reflect.Int ||
		x == reflect.Uint && y == reflect.Uint64 || x == reflect.Uint64 && y == reflect.Uint
}

func equal(a, b reflect.Value) bool {
	if a.Kind() == reflect.Slice && b.Kind() == reflect.Slice {
		if a.Len() != b.Len() {
			return false
		}
		for i := 0; i < a.Len(); i++ {
			if !equal(a.Index(i), b.Index(i)) {
				return false
			}
		}
		return true
	}
	if a.Type() != b.Type() {
		if !sameWidth(a.Type(), b.Type()) || !b.CanConvert(a.Type()) {
			return false
		}
		b = b.Convert(a.Type())
	}
	switch a.Kind() {
	case reflect.Float64:
		x, y := a.Float(), b.Float()
		return math.Float64bits(x) == math.Float64bits(y) || math.IsNaN(x) && math.IsNaN(y)
	case reflect.Struct:
		for i := range a.NumField() {
			if !equal(a.Field(i), b.Field(i)) {
				return false
			}
		}
		return true
	default:
		return a.CanInterface() && b.CanInterface() && reflect.DeepEqual(a.Interface(), b.Interface())
	}
}

func sample(typ reflect.Type, rng *rand.Rand, trial, depth int) (reflect.Value, error) {
	val := reflect.New(typ).Elem()
	switch typ.Kind() {
	case reflect.Bool:
		val.SetBool(trial%2 != 0)
		if trial >= 6 {
			val.SetBool(rng.Uint64()%2 != 0)
		}
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		limit := int64(1) << (typ.Bits() - 1)
		edges := [...]int64{0, 1, -1, -limit, limit - 1, 2}
		n := rng.Int64N(33) - 16
		if trial < len(edges) {
			n = edges[trial]
		} else if trial%2 == 0 {
			shift := 64 - typ.Bits()
			n = int64(rng.Uint64()<<shift) >> shift
		}
		val.SetInt(n)
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		limit := uint64(1) << typ.Bits()
		edges := [...]uint64{0, 1, limit - 1, limit - 2, 2, 3}
		n := rng.Uint64N(33)
		if trial < len(edges) {
			n = edges[trial]
		} else if trial%2 == 0 {
			n = rng.Uint64() & (limit - 1)
		}
		val.SetUint(n)
	case reflect.Float64:
		edges := [...]float64{0, math.Copysign(0, -1), 1, -1, math.SmallestNonzeroFloat64, math.MaxFloat64}
		f := rng.Float64()*32 - 16
		if trial < len(edges) {
			f = edges[trial]
		} else if trial%2 == 0 {
			f = math.Float64frombits(rng.Uint64())
			if math.IsNaN(f) || math.IsInf(f, 0) {
				f = 0
			}
		}
		val.SetFloat(f)
	case reflect.String:
		if named, ok := val.Interface().(interface{ LeanfranDesc() *schema.Desc }); ok {
			if cases := named.LeanfranDesc().Cases; len(cases) > 0 {
				idx := trial
				if idx >= len(cases) {
					idx = rng.IntN(len(cases))
				}
				val.SetString(cases[idx])
				return val, nil
			}
		}
		edges := [...]string{"", "a", "é", "\x00", "界", "🙂"}
		if trial < len(edges) {
			val.SetString(edges[trial])
		} else {
			chars := []rune("abcABC012é界🙂\x00")
			out := make([]rune, rng.IntN(9))
			for i := range out {
				out[i] = chars[rng.IntN(len(chars))]
			}
			val.SetString(string(out))
		}
	case reflect.Slice:
		if depth >= 4 || trial == 0 {
			return val, nil
		}
		length := 1
		if trial >= 6 {
			length = rng.IntN(9)
		}
		val.Set(reflect.MakeSlice(typ, length, length))
		for i := range length {
			v, err := sample(typ.Elem(), rng, trial, depth+1)
			if err != nil {
				return reflect.Value{}, err
			}
			val.Index(i).Set(v)
		}
	case reflect.Struct:
		for i := range typ.NumField() {
			if !val.Field(i).CanSet() {
				return reflect.Value{}, fmt.Errorf("inaccessible field %s.%s", typ, typ.Field(i).Name)
			}
			v, err := sample(typ.Field(i).Type, rng, trial, depth+1)
			if err != nil {
				return reflect.Value{}, err
			}
			val.Field(i).Set(v)
		}
	default:
		return reflect.Value{}, fmt.Errorf("unsupported type %s", typ)
	}
	return val, nil
}
