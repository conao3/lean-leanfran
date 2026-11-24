package verify

import (
	"fmt"
	"go/ast"
	"go/constant"
	"go/token"
	"go/types"
	"math"
	"slices"
	"strings"
	"unicode/utf8"
)

func (t *translation) value(node ast.Expr, typ types.Type) string {
	info := t.model.Info
	if typ == nil {
		typ = info.TypeOf(node)
	}
	if typ == nil {
		t.reject(node, "unresolved Go expression")
	}
	if tv := info.Types[node]; tv.Value != nil {
		name := t.leanType(node, typ)
		switch tv.Value.Kind() {
		case constant.Bool:
			return tv.Value.String()
		case constant.String:
			s := constant.StringVal(tv.Value)
			if !utf8.ValidString(s) {
				t.reject(node, "invalid UTF-8 string constant")
			}
			return leanString(s)
		case constant.Int:
			return "(" + tv.Value.ExactString() + " : " + name + ")"
		case constant.Float:
			f, _ := constant.Float64Val(tv.Value)
			return fmt.Sprintf("(Float.ofBits %d)", math.Float64bits(f))
		}
		t.reject(node, "unsupported Go constant %v", tv.Value)
	}
	switch x := node.(type) {
	case *ast.ParenExpr:
		return t.value(x.X, typ)
	case *ast.Ident:
		obj := info.Uses[x]
		if v := t.locals[obj]; v != "" {
			return v
		}
		if obj == types.Universe.Lookup("nil") {
			if _, ok := types.Unalias(typ).(*types.Slice); ok {
				return "(#[] : " + t.leanType(x, typ) + ")"
			}
		}
		t.reject(x, "read of nonlocal variable %s", x.Name)
	case *ast.UnaryExpr:
		v := t.value(x.X, nil)
		switch x.Op {
		case token.NOT:
			return "(!" + v + ")"
		case token.SUB:
			return "(-" + v + ")"
		case token.ADD:
			return v
		case token.XOR:
			if b := basic(typ); b != nil && b.Info()&types.IsUnsigned != 0 {
				return "(~~~" + v + ")"
			}
		}
		t.reject(x, "unsupported unary operation %s", x.Op)
	case *ast.BinaryExpr:
		leftType := info.TypeOf(x.X)
		rightType := info.TypeOf(x.Y)
		if b := basic(leftType); b != nil && b.Info()&types.IsUntyped != 0 && x.Op != token.SHL && x.Op != token.SHR {
			leftType = rightType
		}
		if b := basic(rightType); b != nil && b.Info()&types.IsUntyped != 0 && x.Op != token.SHL && x.Op != token.SHR {
			rightType = leftType
		}
		if x.Op == token.SHL || x.Op == token.SHR {
			leftType = typ
		}
		a := t.value(x.X, leftType)
		if x.Op == token.SHL || x.Op == token.SHR {
			if c := info.Types[x.Y].Value; c != nil {
				if bt := basic(leftType); bt == nil || bt.Info()&types.IsUnsigned == 0 {
					t.reject(node, "bitwise operation on %v", leftType)
				}
				fn := "Go.shl"
				if x.Op == token.SHR {
					fn = "Go.shr"
				}
				name := t.leanType(x, leftType)
				return apply(fn, strings.TrimPrefix(name, "UInt"), name+".ofNat", a, c.ExactString())
			}
		}
		effects := t.effects
		b := t.value(x.Y, rightType)
		if t.effects > effects && (x.Op == token.LAND || x.Op == token.LOR) {
			name := "Go.andThen"
			if x.Op == token.LOR {
				name = "Go.orElse"
			}
			return t.action(name, a, "(fun _ => do return "+b+")")
		}
		return t.binary(x, x.Op, a, b, leftType, rightType)
	case *ast.SelectorExpr:
		sel := info.Selections[x]
		if sel != nil && sel.Kind() == types.FieldVal && len(sel.Index()) == 1 && !sel.Indirect() {
			if desc, ok := t.namedType(sel.Recv()); ok {
				if field := desc.Fields[x.Sel.Name]; field != "" {
					return "(" + t.value(x.X, nil) + ")." + leanName(field)
				}
			}
		}
		t.reject(x, "unmodeled field access %s", x.Sel.Name)
	case *ast.IndexExpr:
		if _, ok := info.TypeOf(x.X).Underlying().(*types.Slice); !ok {
			t.reject(x, "unsupported indexing: expected a slice")
		}
		return t.action("Go.index", t.value(x.X, nil), t.toInt(x.Index))
	case *ast.CompositeLit:
		if shape, ok := typ.Underlying().(*types.Struct); ok {
			return t.structLiteral(x, typ, shape)
		}
		if _, ok := types.Unalias(typ).(*types.Slice); !ok {
			t.reject(x, "unsupported composite literal %v", typ)
		}
		var values []string
		for _, element := range x.Elts {
			if _, ok := element.(*ast.KeyValueExpr); ok {
				t.reject(element, "keyed slice literal")
			}
			values = append(values, t.value(element, typ.Underlying().(*types.Slice).Elem()))
		}
		return "(#[" + strings.Join(values, ", ") + "] : " + t.leanType(node, typ) + ")"
	case *ast.CallExpr:
		return t.call(x, false)
	}
	t.reject(node, "unsupported Go expression %T", node)
	return ""
}

func leanString(s string) string {
	var out strings.Builder
	out.WriteByte('"')
	for _, r := range s {
		switch r {
		case '\n':
			out.WriteString(`\n`)
		case '\r':
			out.WriteString(`\r`)
		case '\t':
			out.WriteString(`\t`)
		case '"', '\\':
			out.WriteByte('\\')
			out.WriteRune(r)
		default:
			if r < 32 || r == 127 {
				fmt.Fprintf(&out, "\\x%02x", r)
			} else {
				out.WriteRune(r)
			}
		}
	}
	out.WriteByte('"')
	return out.String()
}

func (t *translation) toInt(node ast.Expr) string {
	return t.integer(node, t.value(node, nil), t.model.Info.TypeOf(node), false)
}

func (t *translation) integer(node ast.Node, val string, typ types.Type, nat bool) string {
	b := basic(typ)
	name := t.leanType(node, typ)
	if b == nil || b.Info()&types.IsInteger == 0 {
		t.reject(node, "expected an integer, got %v", typ)
	}
	if b.Info()&types.IsUnsigned != 0 {
		res := apply(name+".toNat", val)
		if nat {
			return res
		}
		return apply("Int.ofNat", res)
	}
	res := apply(name+".toInt", val)
	if nat {
		return apply("Int.toNat", res)
	}
	return res
}

func (t *translation) binary(node ast.Node, op token.Token, a, b string, typ, rhs types.Type) string {
	bt := basic(typ)
	sym := op.String()
	switch op {
	case token.ADD:
		if bt != nil && bt.Info()&types.IsString != 0 {
			sym = "++"
		}
	case token.SUB, token.MUL:
	case token.QUO, token.REM:
		if bt == nil || bt.Info()&(types.IsInteger|types.IsFloat) == 0 {
			t.reject(node, "unsupported division operand %v", typ)
		}
		if bt.Info()&types.IsFloat == 0 {
			action := "Go.div"
			if op == token.REM {
				action = "Go.mod"
			}
			return t.action(action, a, b)
		}
	case token.ARROW:
		t.reject(node, "channel receive")
	case token.AND, token.OR, token.XOR, token.AND_NOT, token.SHL, token.SHR:
		if bt == nil || bt.Info()&types.IsUnsigned == 0 {
			t.reject(node, "bitwise operation on %v", typ)
		}
		switch op {
		case token.AND:
			sym = "&&&"
		case token.OR:
			sym = "|||"
		case token.XOR:
			sym = "^^^"
		case token.AND_NOT:
			sym, b = "&&&", "(~~~"+b+")"
		case token.SHL, token.SHR:
			name := t.leanType(node, typ)
			width := strings.TrimPrefix(name, "UInt")
			shift := "Go.shl"
			if op == token.SHR {
				shift = "Go.shr"
			}
			fn := apply(shift, width, name+".ofNat")
			if rb := basic(rhs); rb != nil && rb.Info()&types.IsUnsigned != 0 {
				return apply(fn, a, t.integer(node, b, rhs, true))
			}
			return t.action("Go.shift", fn, a, t.integer(node, b, rhs, false))
		}
	case token.EQL, token.NEQ:
		equal := t.equal(node, a, b, typ)
		if op == token.NEQ {
			equal = "(!" + equal + ")"
		}
		return equal
	case token.LSS, token.LEQ, token.GTR, token.GEQ:
		if bt == nil {
			t.reject(node, "ordering of unsupported type %v", typ)
		}
		return "(decide (" + a + " " + sym + " " + b + "))"
	case token.LAND, token.LOR:
	default:
		t.reject(node, "unsupported binary operation %s", op)
	}
	return "(" + a + " " + sym + " " + b + ")"
}

func (t *translation) call(x *ast.CallExpr, passError bool) string {
	info := t.model.Info
	id, _ := ast.Unparen(x.Fun).(*ast.Ident)
	var obj types.Object
	if id != nil {
		obj = info.Uses[id]
	} else if sel, ok := ast.Unparen(x.Fun).(*ast.SelectorExpr); ok {
		obj = info.Uses[sel.Sel]
	}
	if info.Types[x.Fun].IsType() {
		typ, source := info.TypeOf(x), info.TypeOf(x.Args[0])
		to, from := basic(typ), basic(source)
		v := t.value(x.Args[0], nil)
		if to != nil && from != nil && to.Info()&types.IsString != 0 && from.Info()&types.IsString != 0 {
			return v
		}
		if to == nil || from == nil || to.Info()&types.IsInteger == 0 || from.Info()&types.IsInteger == 0 {
			t.reject(x, "unsupported conversion from %v to %v", source, typ)
		}
		return apply(t.leanType(x, typ)+".ofInt", t.toInt(x.Args[0]))
	}
	if builtin, ok := obj.(*types.Builtin); ok {
		switch builtin.Name() {
		case "len":
			ty := info.TypeOf(x.Args[0])
			name := "Go.arrayLen"
			if b := basic(ty); b != nil && b.Info()&types.IsString != 0 {
				name = "Go.strLen"
			} else if _, ok := ty.Underlying().(*types.Slice); !ok {
				t.reject(x, "unsupported len argument %v", ty)
			}
			return apply(name, t.value(x.Args[0], nil))
		case "min", "max":
			name := builtin.Name()
			if b := basic(info.TypeOf(x)); b != nil {
				suffix := strings.ToUpper(name[:1]) + name[1:]
				if b.Info()&types.IsFloat != 0 {
					name = "Go.float" + suffix
				} else if b.Info()&types.IsString != 0 {
					name = apply("Go.string"+suffix, "id")
				}
			}
			val := t.value(x.Args[0], info.TypeOf(x))
			for _, a := range x.Args[1:] {
				val = apply(name, val, t.value(a, info.TypeOf(x)))
			}
			return val
		}
	}
	if f, ok := obj.(*types.Func); ok && f.Pkg() != nil {
		if desc, ok := t.namedType(info.TypeOf(x)); ok && f.Pkg().Path() == desc.Path && len(x.Args) == 0 {
			if ctor := desc.Constructors[f.Name()]; ctor != "" {
				return leanName(desc.Lean) + "." + leanName(ctor)
			}
		}
		callee := t.resolve(f, x.Pos())
		if callee.errorPair && !passError {
			t.reject(x, "an error-returning model can only be used in a direct return")
		}
		signature := f.Signature()
		if len(x.Args) != signature.Params().Len() || x.Ellipsis.IsValid() {
			t.reject(x, "unsupported modeled call argument list")
		}
		var args []string
		for i, a := range x.Args {
			args = append(args, t.value(a, signature.Params().At(i).Type()))
		}
		if mod := callee.Module(); !slices.Contains(t.def.Imports, mod) {
			t.def.Imports = append(t.def.Imports, mod)
		}
		if callee.Fallible {
			return t.action(leanName(callee.Model.Name()), args...)
		}
		return apply(leanName(callee.Model.Name()), args...)
	}
	t.reject(x, "unsupported call %s", types.ExprString(x.Fun))
	return ""
}
