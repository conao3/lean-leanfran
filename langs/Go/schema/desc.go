package schema

import "github.com/conao3/leanfran-go/rt"

type Desc struct {
	Kind          string
	Name          string
	GoType        string
	Bits          int
	Bound         string
	First, Second *Desc
	Variants      []Variant
	Cases         []string
	Bounds        map[string]string
	Ref           func() *Desc
}

type Variant struct {
	Name                 string
	Tag                  uint16
	Objects, ScalarBytes int
	Trivial              bool
	Positional           bool
	Fields               []Field
}

type Field struct {
	Key            string
	Desc           *Desc
	Slot           string
	Offset         int
	Flat, OmitNone bool
	Bounds         map[string]string
}

func (d *Desc) resolve() *Desc {
	for d.Ref != nil {
		d = d.Ref()
	}
	return d
}

func (v Variant) Build(fields []rt.V) rt.V {
	if v.Trivial {
		return fields[0]
	}
	if v.Objects == 0 && v.ScalarBytes == 0 {
		return rt.Lean_box(uint64(v.Tag))
	}
	value := rt.Lean_alloc_ctor(v.Tag, v.Objects, v.ScalarBytes)
	for i, f := range v.Fields {
		x := fields[i]
		switch f.Slot {
		case "obj":
			rt.Lean_ctor_set(value, f.Offset, x)
		case "usize":
			rt.Lean_ctor_set_usize(value, f.Offset, rt.Lean_unbox(x))
		case "u8":
			rt.Lean_ctor_set_uint8(value, f.Offset, uint8(rt.Lean_unbox(x)))
		case "u16":
			rt.Lean_ctor_set_uint16(value, f.Offset, uint16(rt.Lean_unbox(x)))
		case "u32", "f32":
			rt.Lean_ctor_set_uint32(value, f.Offset, uint32(rt.Lean_unbox(x)))
		case "u64", "f64":
			rt.Lean_ctor_set_uint64(value, f.Offset, rt.Lean_unbox(x))
		default:
			rt.Lean_internal_panic("unknown field slot " + f.Slot)
		}
	}
	return value
}

func (v Variant) Get(value rt.V, i int) rt.V {
	if v.Trivial {
		return value
	}
	f := v.Fields[i]
	switch f.Slot {
	case "obj":
		return rt.Lean_ctor_get(value, f.Offset)
	case "usize":
		return rt.Lean_box(rt.Lean_ctor_get_usize(value, f.Offset))
	case "u8":
		return rt.Lean_box(uint64(rt.Lean_ctor_get_uint8(value, f.Offset)))
	case "u16":
		return rt.Lean_box(uint64(rt.Lean_ctor_get_uint16(value, f.Offset)))
	case "u32", "f32":
		return rt.Lean_box(uint64(rt.Lean_ctor_get_uint32(value, f.Offset)))
	case "u64", "f64":
		return rt.Lean_box(rt.Lean_ctor_get_uint64(value, f.Offset))
	default:
		rt.Lean_internal_panic("unknown field slot " + f.Slot)
		return rt.V{}
	}
}

func (d *Desc) dataKind() string {
	if d.Kind == "model" {
		if len(d.Cases) != 0 {
			return "enum"
		}
		return "struct"
	}
	return d.Kind
}
