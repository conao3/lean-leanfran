package verify

import (
	"fmt"
	"go/ast"
	"go/types"
	"slices"
	"strings"
)

func (t *translation) structure(node ast.Node, typ types.Type, init map[int]string) string {
	desc, ok := t.namedType(typ)
	shape, structure := typ.Underlying().(*types.Struct)
	if !ok || !structure || desc.Invariants {
		t.reject(node, "unsupported construction of %v", typ)
	}
	fields := make([]string, shape.NumFields())
	for i := range shape.NumFields() {
		field := shape.Field(i)
		name, ok := desc.Fields[field.Name()]
		if !ok {
			t.reject(node, "missing Lean field for %s.%s", typ, field.Name())
		}
		value, exists := init[i]
		if !exists {
			value = t.zero(node, field.Type())
		}
		fields[i] = leanName(name) + " := " + value
	}
	return "({ " + strings.Join(fields, ", ") + " } : " + t.leanType(node, typ) + ")"
}

func (t *translation) structLiteral(x *ast.CompositeLit, typ types.Type, shape *types.Struct) string {
	if desc, ok := t.namedType(typ); ok && desc.ZeroCase != "" && len(x.Elts) == 0 {
		return t.zero(x, typ)
	}
	values := make(map[int]string)
	var binds strings.Builder
	for i, item := range x.Elts {
		index, value := i, item
		if kv, ok := item.(*ast.KeyValueExpr); ok {
			key := kv.Key.(*ast.Ident).Name
			value = kv.Value
			for j := range shape.NumFields() {
				if shape.Field(j).Name() == key {
					index = j
					break
				}
			}
		}
		tmp := t.next()
		fmt.Fprintf(&binds, "let %s := %s; ", tmp, t.value(value, shape.Field(index).Type()))
		values[index] = tmp
	}
	return "(" + binds.String() + t.structure(x, typ, values) + ")"
}

func (t *translation) equal(node ast.Node, a, b string, typ types.Type) string {
	desc, named := t.namedType(typ)
	if named && desc.Cases != nil {
		return "(" + enumString(desc, a) + " == " + enumString(desc, b) + ")"
	}
	if base := basic(typ); base != nil && basicTypes[base.Kind()] != "" {
		return "(" + a + " == " + b + ")"
	}
	shape, ok := typ.Underlying().(*types.Struct)
	if !ok || !named {
		t.reject(node, "unsupported Go equality of %v", typ)
	}
	x, y := t.next(), t.next()
	parts := make([]string, shape.NumFields())
	for i := range shape.NumFields() {
		field := shape.Field(i)
		key := "." + leanName(desc.Fields[field.Name()])
		parts[i] = t.equal(node, x+key, y+key, field.Type())
	}
	if len(parts) == 0 {
		parts = []string{"true"}
	}
	return "(let " + x + " := " + a + "; let " + y + " := " + b + "; " + strings.Join(parts, " && ") + ")"
}

func enumString(desc NamedType, val string) string {
	values := make([]string, 0, len(desc.Cases))
	for value := range desc.Cases {
		values = append(values, value)
	}
	slices.Sort(values)
	var match strings.Builder
	fmt.Fprintf(&match, "(match %s with", val)
	for _, value := range values {
		fmt.Fprintf(&match, " | %s.%s => %s", leanName(desc.Lean), leanName(desc.Cases[value]), leanString(value))
	}
	match.WriteByte(')')
	return match.String()
}
