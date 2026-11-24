package verify

import (
	"fmt"
	"go/ast"
	"go/token"
	"go/types"
	"slices"
	"strconv"
	"strings"
)

type Definition struct {
	Model       *Function
	Source      string
	Fallible    bool
	Imports     []string
	TypeImports []string
	Err         error
	errorPair   bool
}

type translation struct {
	model   *Function
	def     *Definition
	resolve func(*types.Func, token.Pos) *Definition
	locals  map[types.Object]string
	fresh   map[types.Object]bool
	depth   int
	count   int
	effects int
	body    strings.Builder
	result  *types.Tuple
}

type unsupported struct{ error }

func (t *translation) reject(node ast.Node, format string, args ...any) {
	panic(unsupported{t.model.problem(node.Pos(), format, args...)})
}

func (d *Definition) Module() string {
	return ModelModule(d.Model.Package) + ".F_" + d.Model.Decl.Name.Name
}

func Definitions(models []*Function) []*Definition {
	byName := make(map[string]*Function)
	for _, m := range models {
		byName[m.Name()] = m
	}
	compiled := make(map[*Function]*Definition)
	active := make(map[*Function]bool)
	var ordered []*Definition
	var compile func(*Function) *Definition
	compile = func(m *Function) *Definition {
		if d := compiled[m]; d != nil {
			return d
		}
		active[m] = true
		d := &Definition{Model: m, Err: m.Err}
		if d.Err == nil {
			t := translation{model: m, def: d, locals: make(map[types.Object]string), fresh: make(map[types.Object]bool)}
			t.resolve = func(fn *types.Func, pos token.Pos) *Definition {
				callee := byName[ModelModule(fn.Pkg().Path())+"."+fn.Name()]
				if callee == nil || fn.Signature().Recv() != nil {
					panic(unsupported{m.problem(pos, "call to unmodeled function %s", fn.FullName())})
				}
				if active[callee] {
					panic(unsupported{m.problem(pos, "recursive model call to %s", fn.FullName())})
				}
				result := compile(callee)
				if result.Err != nil {
					panic(unsupported{m.problem(pos, "call to unextracted model %s", fn.FullName())})
				}
				return result
			}
			d.Err = t.translate()
		}
		delete(active, m)
		compiled[m] = d
		ordered = append(ordered, d)
		return d
	}
	for _, m := range models {
		compile(m)
	}
	return ordered
}

func (t *translation) translate() (err error) {
	defer func() {
		if caught := recover(); caught != nil {
			if rejected, ok := caught.(unsupported); ok {
				err = rejected.error
				return
			}
			panic(caught)
		}
	}()
	fn := t.model.Decl
	if t.model.Info == nil || fn.Body == nil || fn.Type.TypeParams != nil || !dotted.MatchString(fn.Name.Name) {
		t.reject(fn, "expected a typed, non-generic Go function with a body and an ASCII name")
	}
	obj, ok := t.model.Info.Defs[fn.Name].(*types.Func)
	if !ok {
		t.reject(fn, "cannot resolve Go function")
	}
	sig := obj.Signature()
	if sig.Variadic() {
		t.reject(fn, "variadic function")
	}
	t.result = sig.Results()
	n := t.result.Len()
	if n == 2 && types.Identical(t.result.At(1).Type(), types.Universe.Lookup("error").Type()) {
		t.def.Fallible = true
		t.def.errorPair = true
		n--
	}
	var resultTypes []string
	for i := range n {
		resultTypes = append(resultTypes, t.leanType(fn.Type.Results, t.result.At(i).Type()))
	}
	typ := "Unit"
	if n > 0 {
		typ = strings.Join(resultTypes, " × ")
	}
	var binders, args []string
	for i := range sig.Params().Len() {
		param := sig.Params().At(i)
		name := t.variable(param)
		binders = append(binders, "("+name+" : "+t.leanType(fn.Type.Params, param.Type())+")")
		args = append(args, name)
	}
	t.depth = 1
	for _, param := range args {
		t.line("let mut %s := %s", param, param)
	}
	for i := range n {
		ret := t.result.At(i)
		if ret.Name() != "" {
			name := t.variable(ret)
			t.line("let mut %s : %s := %s", name, resultTypes[i], t.zero(fn.Type.Results, ret.Type()))
		}
	}
	if t.def.errorPair && t.result.At(1).Name() != "" {
		t.reject(fn.Type.Results, "named error result")
	}
	t.block(fn.Body.List)
	if n == 0 {
		t.line("return ()")
	}
	if t.body.Len() == 0 {
		t.reject(fn, "empty function body")
	}
	mode := "Id.run do"
	if t.def.Fallible {
		mode = "do"
		typ = "Go.M (" + typ + ")"
	}
	model := leanName(t.model.Name())
	binder := strings.Join(binders, " ")
	var out strings.Builder
	fmt.Fprintf(&out, "def %s %s : %s := %s\n%s\n", model, binder, typ, mode, t.body.String())
	for _, check := range t.model.Checks {
		predicate := embedName(t.model.Spec) + "." + leanName(check.Name)
		requires := ""
		if t.model.Needs != "" {
			requires = apply(embedName(t.model.Spec)+"."+leanName(t.model.Needs), args...) + " = true → "
		}
		quantified := ""
		if binder != "" {
			quantified = "∀ " + binder + ", "
		}
		call := apply(model, args...)
		var proposition string
		switch {
		case check.Label == "refines":
			want := apply(predicate, args...)
			if t.def.Fallible {
				want = "Except.ok " + want
			}
			proposition = call + " = " + want
		case t.def.Fallible:
			proposition = "∀ r, " + call + " = Except.ok r → " + apply(predicate, append(args, "r")...) + " = true"
		default:
			proposition = apply(predicate, append(args, call)...) + " = true"
		}
		fmt.Fprintf(&out, "abbrev %s.obligation.%s : Prop := %s%s%s\n", model, leanName(check.Label), quantified, requires, proposition)
	}
	t.def.Source = out.String()
	return nil
}

func embedName(path string) string {
	return strings.Replace(ModelModule(path), "LeanGoModel", "LeanGoEmbed", 1)
}

func leanName(name string) string {
	parts := strings.Split(name, ".")
	for i, part := range parts {
		parts[i] = "«" + part + "»"
	}
	return strings.Join(parts, ".")
}

func apply(fn string, args ...string) string {
	if len(args) == 0 {
		return fn
	}
	return "(" + fn + " " + strings.Join(args, " ") + ")"
}

func (t *translation) line(format string, args ...any) {
	t.body.WriteString(strings.Repeat("  ", t.depth))
	fmt.Fprintf(&t.body, format, args...)
	t.body.WriteByte('\n')
}

func (t *translation) next() string {
	t.count++
	return "_v" + strconv.Itoa(t.count)
}

func (t *translation) variable(obj types.Object) string {
	if name := t.locals[obj]; name != "" {
		return name
	}
	name := t.next()
	t.locals[obj] = name
	return name
}

func (t *translation) action(fn string, args ...string) string {
	t.def.Fallible = true
	t.effects++
	return "(← " + apply(fn, args...) + ")"
}

var basicTypes = map[types.BasicKind]string{
	types.Int: "Int64", types.Int8: "Int8", types.Int16: "Int16", types.Int32: "Int32", types.Int64: "Int64",
	types.Uint: "UInt64", types.Uint8: "UInt8", types.Uint16: "UInt16", types.Uint32: "UInt32", types.Uint64: "UInt64",
	types.Bool: "Bool", types.String: "String", types.Float64: "Float",
	types.UntypedInt: "Int64", types.UntypedBool: "Bool", types.UntypedString: "String", types.UntypedFloat: "Float",
	types.UntypedRune: "Int32",
}

func basic(typ types.Type) *types.Basic {
	if typ == nil {
		return nil
	}
	b, _ := typ.Underlying().(*types.Basic)
	return b
}

func (t *translation) namedType(typ types.Type) (NamedType, bool) {
	if typ != nil {
		if n, ok := types.Unalias(typ).(*types.Named); ok && n.Obj().Pkg() != nil {
			v, exists := t.model.Named[n.Obj().Pkg().Path()+"."+n.Obj().Name()]
			return v, exists
		}
	}
	return NamedType{}, false
}

func (t *translation) leanType(node ast.Node, typ types.Type) string {
	if named, ok := t.namedType(typ); ok {
		if !slices.Contains(t.def.TypeImports, named.Module) && named.Module != embedName(t.model.Spec) {
			t.def.TypeImports = append(t.def.TypeImports, named.Module)
		}
		if shape, ok := typ.Underlying().(*types.Struct); ok && named.Cases == nil {
			for field := range shape.Fields() {
				if _, exists := named.Fields[field.Name()]; !exists {
					t.reject(node, "no Lean field for %s.%s", typ, field.Name())
				}
				t.leanType(node, field.Type())
			}
		}
		return leanName(named.Lean)
	}
	if b := basic(typ); b != nil && basicTypes[b.Kind()] != "" {
		if _, named := types.Unalias(typ).(*types.Named); !named || b.Kind() == types.String {
			return basicTypes[b.Kind()]
		}
	}
	if typ != nil {
		if s, ok := types.Unalias(typ).(*types.Slice); ok {
			return "(Array " + t.leanType(node, s.Elem()) + ")"
		}
	}
	t.reject(node, "unsupported Go type %v", typ)
	return ""
}

func tuple(values []string) string {
	switch len(values) {
	case 0:
		return "()"
	case 1:
		return values[0]
	default:
		return "(" + strings.Join(values, ", ") + ")"
	}
}
