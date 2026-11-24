package schema

import (
	"encoding/json"
	"math"
	"math/big"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/conao3/leanfran-go/rt"
)

func Payload(d *Desc, v rt.V) any {
	d = d.resolve()
	n := rt.Lean_unbox(v)
	switch d.dataKind() {
	case "nat", "fin":
		return json.Number(rt.NatString(v))
	case "int":
		return json.Number(rt.IntString(v))
	case "uint", "usize":
		if d.Bits == 64 {
			return strconv.FormatUint(n, 10)
		}
		return n
	case "sint", "isize":
		return signed(n, d.Bits)
	case "bool":
		return n != 0
	case "string":
		return rt.String(v)
	case "char":
		return string(rune(n))
	case "unit":
		return map[string]any{}
	case "float":
		return floatJSON(rt.Lean_unbox_float(v))
	case "float32":
		return floatJSON(float64(rt.Lean_unbox_float32(v)))
	case "bytes":
		bytes := rt.Bytes(v)
		out := make([]uint, len(bytes))
		for i, b := range bytes {
			out[i] = uint(b)
		}
		return out
	case "option":
		if rt.Lean_obj_tag(v) == 0 {
			return nil
		}
		return Payload(d.First, rt.Lean_ctor_get(v, 0))
	case "list":
		out := []any{}
		for rt.Lean_obj_tag(v) != 0 {
			out = append(out, Payload(d.First, rt.Lean_ctor_get(v, 0)))
			v = rt.Lean_ctor_get(v, 1)
		}
		return out
	case "array":
		out := make([]any, rt.Lean_array_size(v))
		for i := range out {
			out[i] = Payload(d.First, rt.Lean_array_uget_borrowed(v, uint64(i)))
		}
		return out
	case "prod":
		return []any{Payload(d.First, rt.Lean_ctor_get(v, 0)), Payload(d.Second, rt.Lean_ctor_get(v, 1))}
	case "except":
		item := rt.Lean_ctor_get(v, 0)
		if rt.Lean_obj_tag(v) == 0 {
			return map[string]any{"error": Payload(d.First, item)}
		}
		return map[string]any{"ok": Payload(d.Second, item)}
	case "enum":
		return d.Cases[n]
	case "subtype":
		return Payload(d.First, v)
	case "struct":
		return recordPayload(d.Variants[0], v)
	case "inductive":
		for _, variant := range d.Variants {
			if !variant.Trivial && uint64(variant.Tag) != rt.Lean_obj_tag(v) {
				continue
			}
			if len(variant.Fields) == 0 {
				return variant.Name
			}
			if !variant.Positional {
				return map[string]any{variant.Name: recordPayload(variant, v)}
			}
			items := make([]any, len(variant.Fields))
			for i, field := range variant.Fields {
				items[i] = Payload(field.Desc, variant.Get(v, i))
			}
			var payload any = items
			if len(items) == 1 {
				payload = items[0]
			}
			return map[string]any{variant.Name: payload}
		}
	}
	rt.Lean_internal_panic("invalid JSON descriptor: " + d.Kind)
	return nil
}

func signed(n uint64, bits int) int64 {
	return int64(n<<(64-bits)) >> (64 - bits)
}

func floatJSON(x float64) any {
	switch {
	case math.IsNaN(x):
		return "NaN"
	case math.IsInf(x, 1):
		return "Infinity"
	case math.IsInf(x, -1):
		return "-Infinity"
	default:
		s := strings.TrimRight(strings.TrimRight(strconv.FormatFloat(x, 'f', 6, 64), "0"), ".")
		if s == "-0" {
			s = "0"
		}
		return json.Number(s)
	}
}

func recordPayload(variant Variant, value rt.V) map[string]any {
	out := make(map[string]any)
	for i, field := range variant.Fields {
		v := variant.Get(value, i)
		if field.OmitNone && rt.Lean_obj_tag(v) == 0 {
			continue
		}
		item := Payload(field.Desc, v)
		if field.Flat {
			for key, value := range item.(map[string]any) {
				out[key] = value
			}
		} else {
			out[field.Key] = item
		}
	}
	return out
}

type Report func(message string, path ...any)

func Parse(d *Desc, value any, report Report) rt.V {
	d = d.resolve()
	switch d.dataKind() {
	case "nat", "int", "fin":
		num, ok := value.(json.Number)
		if n, parsed := new(big.Int).SetString(string(num), 10); ok && parsed {
			if d.Kind == "int" {
				return rt.IntFromBig(n)
			}
			if n.Sign() >= 0 {
				if d.Kind != "fin" {
					return rt.NatFromBig(n)
				}
				bound, _ := new(big.Int).SetString(d.Bound, 10)
				if n.Cmp(bound) < 0 {
					return rt.NatFromBig(n)
				}
			}
		}
	case "uint", "usize":
		var s string
		if d.Bits == 64 {
			s, _ = value.(string)
		} else if n, ok := value.(json.Number); ok {
			s = string(n)
		}
		if v, err := strconv.ParseUint(s, 10, d.Bits); err == nil {
			return rt.Lean_box(v)
		}
	case "sint", "isize":
		if s, ok := value.(json.Number); ok {
			if v, err := strconv.ParseInt(string(s), 10, d.Bits); err == nil {
				return rt.Lean_box(uint64(v))
			}
		}
	case "float", "float32":
		bits := 64
		if d.Kind == "float32" {
			bits = 32
		}
		if f, ok := parseFloat(value, bits); ok {
			if bits == 32 {
				return rt.Lean_box_float32(float32(f))
			}
			return rt.Lean_box_float(f)
		}
	case "bool":
		if b, ok := value.(bool); ok {
			return rt.Lean_box(uint64(rt.Bool(b)))
		}
	case "string":
		if s, ok := value.(string); ok {
			return rt.Lean_mk_string(s)
		}
	case "char":
		if s, ok := value.(string); ok && utf8.RuneCountInString(s) == 1 {
			r, _ := utf8.DecodeRuneInString(s)
			return rt.Lean_box(uint64(r))
		}
	case "unit":
		if object, ok := value.(map[string]any); ok && len(object) == 0 {
			return rt.V{}
		}
	case "option":
		if value == nil {
			return rt.V{}
		}
		return constructor(1, Parse(d.First, value, report))
	case "list", "array", "bytes":
		if array, ok := value.([]any); ok {
			return parseSequence(d, array, report)
		}
	case "prod":
		if array, ok := value.([]any); ok && len(array) == 2 {
			return constructor(0, Parse(d.First, array[0], at(report, 0)), Parse(d.Second, array[1], at(report, 1)))
		}
	case "except":
		if object, ok := value.(map[string]any); ok && len(object) == 1 {
			if item, exists := object["error"]; exists {
				return constructor(0, Parse(d.First, item, at(report, "error")))
			}
			if item, exists := object["ok"]; exists {
				return constructor(1, Parse(d.Second, item, at(report, "ok")))
			}
		}
	case "enum":
		for i, name := range d.Cases {
			if s, ok := value.(string); ok && s == name {
				return rt.Lean_box(uint64(i))
			}
		}
	case "subtype":
		return Parse(d.First, value, report)
	case "struct":
		if object, ok := value.(map[string]any); ok {
			return parseRecord(d.Variants[0], object, report)
		}
	case "inductive":
		for _, variant := range d.Variants {
			if len(variant.Fields) == 0 {
				if s, ok := value.(string); ok && s == variant.Name {
					return variant.Build(nil)
				}
				continue
			}
			if object, ok := value.(map[string]any); ok && len(object) == 1 {
				if payload, exists := object[variant.Name]; exists {
					return parseVariant(variant, payload, at(report, variant.Name))
				}
			}
		}
	}
	kind := d.Kind
	if d.Name != "" {
		kind = d.Name
	}
	report("expected " + kind)
	return rt.V{}
}

func parseFloat(value any, bits int) (float64, bool) {
	switch v := value.(type) {
	case string:
		switch v {
		case "NaN":
			return math.NaN(), true
		case "Infinity":
			return math.Inf(1), true
		case "-Infinity":
			return math.Inf(-1), true
		}
	case json.Number:
		x, err := strconv.ParseFloat(string(v), bits)
		return x, err == nil
	}
	return 0, false
}

func at(report Report, segment any) Report {
	return func(message string, path ...any) {
		report(message, append([]any{segment}, path...)...)
	}
}

func constructor(tag uint16, fields ...rt.V) rt.V {
	out := rt.Lean_alloc_ctor(tag, len(fields), 0)
	for i, field := range fields {
		rt.Lean_ctor_set(out, i, field)
	}
	return out
}

func parseSequence(d *Desc, values []any, report Report) rt.V {
	switch d.dataKind() {
	case "bytes":
		item := Desc{Kind: "uint", Bits: 8}
		out := make([]byte, len(values))
		for i, v := range values {
			out[i] = byte(rt.Lean_unbox(Parse(&item, v, at(report, i))))
		}
		return rt.BytesFromSlice(out)
	case "array":
		out := rt.Lean_mk_empty_array_with_capacity(rt.NatFromUint64(uint64(len(values))))
		for i, v := range values {
			out = rt.Lean_array_push(out, Parse(d.First, v, at(report, i)))
		}
		return out
	default:
		items := make([]rt.V, len(values))
		for i, v := range values {
			items[i] = Parse(d.First, v, at(report, i))
		}
		var out rt.V
		for i := len(items) - 1; i >= 0; i-- {
			out = constructor(1, items[i], out)
		}
		return out
	}
}

func parseRecord(variant Variant, object map[string]any, report Report) rt.V {
	fields := make([]rt.V, len(variant.Fields))
	for i, field := range variant.Fields {
		if field.Flat {
			fields[i] = Parse(field.Desc, object, report)
			continue
		}
		item, ok := object[field.Key]
		if !ok && field.Desc.resolve().Kind != "option" {
			report("missing field", field.Key)
			continue
		}
		fields[i] = Parse(field.Desc, item, at(report, field.Key))
	}
	return variant.Build(fields)
}

func parseVariant(variant Variant, payload any, report Report) rt.V {
	if !variant.Positional {
		if object, ok := payload.(map[string]any); ok {
			return parseRecord(variant, object, report)
		}
		report("expected constructor fields")
		return rt.V{}
	}
	if len(variant.Fields) == 1 {
		return variant.Build([]rt.V{Parse(variant.Fields[0].Desc, payload, report)})
	}
	if array, ok := payload.([]any); ok && len(array) == len(variant.Fields) {
		fields := make([]rt.V, len(array))
		for i, f := range variant.Fields {
			fields[i] = Parse(f.Desc, array[i], at(report, i))
		}
		return variant.Build(fields)
	}
	report("expected positional constructor fields")
	return rt.V{}
}
