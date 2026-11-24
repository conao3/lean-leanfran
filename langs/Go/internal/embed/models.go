package embed

import (
	"encoding/hex"
	"fmt"
	"go/ast"
	"go/constant"
	"go/importer"
	"go/token"
	"go/types"
	"io"
	"math/big"
	"os"
	"reflect"
	"strings"
	"unicode/utf8"
)

type model struct {
	Lean       string            `json:"lean"`
	Path       string            `json:"path"`
	Name       string            `json:"name"`
	Fields     map[string]string `json:"fields,omitempty"`
	Cases      map[string]string `json:"cases,omitempty"`
	Plain      bool              `json:"plain,omitempty"`
	Restricted bool              `json:"restricted,omitempty"`
	Source     string            `json:"-"`
}

type modelImporter struct {
	p      *project
	cache  map[string]*types.Package
	active map[string]bool
	info   map[string]*types.Info
	binary types.Importer
	strict bool
	errors map[string]error
}

func (i *modelImporter) Import(path string) (*types.Package, error) {
	if pkg := i.p.packages[path]; pkg != nil {
		out, _, err := i.check(pkg)
		if out != nil && (!i.strict || err == nil) {
			return out, nil
		}
		return nil, err
	}
	return i.binary.Import(path)
}

func (i *modelImporter) check(pkg *goPackage) (*types.Package, *types.Info, error) {
	if out := i.cache[pkg.path]; out != nil {
		return out, i.info[pkg.path], i.errors[pkg.path]
	}
	if i.active[pkg.path] {
		return nil, nil, fmt.Errorf("import cycle at %s", pkg.path)
	}
	i.active[pkg.path] = true
	defer delete(i.active, pkg.path)
	info := &types.Info{
		Types:      make(map[ast.Expr]types.TypeAndValue),
		Defs:       make(map[*ast.Ident]types.Object),
		Uses:       make(map[*ast.Ident]types.Object),
		Selections: make(map[*ast.SelectorExpr]*types.Selection),
	}
	conf := types.Config{Importer: i, Sizes: types.SizesFor("gc", "amd64"), Error: func(error) {}}
	out, err := conf.Check(pkg.path, pkg.fset, pkg.files, info)
	if out != nil {
		i.cache[pkg.path] = out
		i.info[pkg.path] = info
		if i.strict {
			i.errors[pkg.path] = err
		}
	}
	return out, info, err
}

func (i *modelImporter) initBinary(files *token.FileSet) {
	p := i.p
	if i.binary == nil {
		i.binary = importer.ForCompiler(files, "gc", func(path string) (io.ReadCloser, error) {
			cmd := command(p.root, "go", "list", "-export", "-f", "{{.Export}}", path)
			cmd.Env = append(os.Environ(), "GOWORK=off")
			out, err := cmd.Output()
			if err != nil {
				return nil, processError(err)
			}
			return os.Open(strings.TrimSpace(string(out)))
		})
	}
}

func (p *project) loadModels() error {
	i := &modelImporter{p: p, cache: make(map[string]*types.Package), active: make(map[string]bool), info: make(map[string]*types.Info)}
	for _, path := range sortedKeys(p.blocks) {
		b := p.blocks[path]
		if len(b.modelExprs) == 0 {
			continue
		}
		i.initBinary(b.pkg.fset)
		_, info, checkErr := i.check(b.pkg)
		if info == nil {
			return b.errorf("Models: %v", checkErr)
		}
		builder := modelBuilder{done: make(map[string]*model), active: make(map[string]bool)}
		values := modelBuilder{plain: true, done: make(map[string]*model), active: make(map[string]bool)}
		for _, expr := range b.modelExprs {
			typeExpr := expr
			if call, ok := expr.(*ast.CallExpr); ok {
				if len(call.Args) != 1 || !info.Types[call.Fun].IsType() {
					return b.errorf("Models expects a string type conversion")
				}
				if _, err := stringLiteral(call.Args[0]); err != nil {
					return b.errorf("Models: %v", err)
				}
				typeExpr = call.Fun
			}
			if lit, ok := expr.(*ast.CompositeLit); ok {
				typeExpr = lit.Type
			}
			t := info.TypeOf(typeExpr)
			if t == nil {
				return b.errorf("cannot resolve model %s: %v", types.ExprString(expr), checkErr)
			}
			named, ok := types.Unalias(t).(*types.Named)
			if !ok {
				return b.errorf("Models expects a named struct or string type: %s", t)
			}
			switch expr.(type) {
			case *ast.CallExpr:
				basic, ok := named.Underlying().(*types.Basic)
				if !ok || basic.Kind() != types.String {
					return b.errorf("Models expects a string type conversion: %s", t)
				}
			case *ast.CompositeLit:
				if _, ok := named.Underlying().(*types.Struct); !ok {
					return b.errorf("Models expects a struct literal: %s", t)
				}
			}
			if _, err := builder.add(named); err != nil {
				return b.errorf("Models: %v", err)
			}
			if tagged, supported := needsPlainModel(named, make(map[types.Type]bool)); tagged && supported {
				if _, err := values.add(named); err != nil {
					return b.errorf("Models: %v", err)
				}
			}
		}
		b.models = append(builder.ordered, values.ordered...)
	}
	return nil
}

func needsPlainModel(typ types.Type, active map[types.Type]bool) (tagged, supported bool) {
	t := types.Unalias(typ)
	switch x := t.(type) {
	case *types.Named:
		st, ok := x.Underlying().(*types.Struct)
		if !ok || active[t] {
			return false, false
		}
		active[t] = true
		defer delete(active, t)
		for i := 0; i < st.NumFields(); i++ {
			if _, ok := reflect.StructTag(st.Tag(i)).Lookup("leanfran"); ok {
				tagged = true
			}
			nested, ok := needsPlainModel(st.Field(i).Type(), active)
			if !ok {
				return false, false
			}
			tagged = tagged || nested
		}
		return tagged, true
	case *types.Slice:
		return needsPlainModel(x.Elem(), active)
	case *types.Basic:
		return false, leanBasics[x.Name()] != "" && x.Kind() != types.Float32
	default:
		return false, false
	}
}

type modelBuilder struct {
	plain   bool
	done    map[string]*model
	active  map[string]bool
	ordered []*model
}

func leanIdent(name string) string { return "«" + name + "»" }

func (b *modelBuilder) add(t *types.Named) (*model, error) {
	obj := t.Obj()
	if obj.Pkg() == nil || !obj.Exported() || t.TypeParams().Len() > 0 {
		return nil, fmt.Errorf("unsupported model type %s", t)
	}
	name := obj.Name()
	path := obj.Pkg().Path()
	prefix := "LeanGoModels.P"
	if b.plain {
		prefix = "LeanGoModels.V"
	}
	ns := prefix + hex.EncodeToString([]byte(path))
	key := ns + "." + name
	if existing := b.done[key]; existing != nil {
		return existing, nil
	}
	if b.active[key] {
		return nil, fmt.Errorf("recursive model type %s", t)
	}
	b.active[key] = true
	defer delete(b.active, key)
	m := &model{Lean: key, Path: path, Name: name, Plain: b.plain}
	var src strings.Builder
	fmt.Fprintf(&src, "\nnamespace %s\n", ns)
	switch typ := t.Underlying().(type) {
	case *types.Struct:
		if !b.plain {
			tagged, supported := needsPlainModel(t, make(map[types.Type]bool))
			m.Restricted = tagged || !supported
		}
		m.Fields = make(map[string]string)
		fmt.Fprintf(&src, "structure %s where\n", leanIdent(name))
		claims := make(map[string]bool)
		for field := range typ.Fields() {
			claims[field.Name()] = true
		}
		for idx := range typ.NumFields() {
			field := typ.Field(idx)
			if !field.Exported() || field.Embedded() {
				return nil, fmt.Errorf("%s.%s has unsupported field type %s (expected an explicitly named exported field)", t, field.Name(), field.Type())
			}
			var tags map[string]string
			if !b.plain {
				var err error
				tags, err = fieldTags(typ.Tag(idx))
				if err != nil {
					return nil, fmt.Errorf("%s.%s: %w", t, field.Name(), err)
				}
			}
			asNat := tags["ge"] == "0" && isBigInt(field.Type())
			lean, goShape, err := b.fieldType(field.Type(), asNat)
			if err != nil {
				return nil, fmt.Errorf("%s.%s: %w", t, field.Name(), err)
			}
			m.Fields[field.Name()] = goShape
			fmt.Fprintf(&src, "  %s : %s\n", leanIdent(field.Name()), lean)
			for _, tag := range sortedKeys(tags) {
				suffix, expr, err := constraint(field.Name(), lean, tag, tags[tag])
				if err != nil {
					return nil, fmt.Errorf("%s.%s: %w", t, field.Name(), err)
				}
				proof := field.Name() + suffix
				if claims[proof] {
					return nil, fmt.Errorf("%s.%s: proof field %s conflicts with a model field", t, field.Name(), proof)
				}
				claims[proof] = true
				fmt.Fprintf(&src, "  %s : %s\n", leanIdent(proof), expr)
			}
		}
	case *types.Basic:
		if typ.Kind() != types.String {
			return nil, fmt.Errorf("unsupported model type %s", t)
		}
		m.Cases = make(map[string]string)
		seen := make(map[string]bool)
		fmt.Fprintf(&src, "inductive %s where\n", leanIdent(name))
		scope := obj.Pkg().Scope()
		for _, id := range scope.Names() {
			c, ok := scope.Lookup(id).(*types.Const)
			if !ok || !types.Identical(c.Type(), t) {
				continue
			}
			if c.Val().Kind() != constant.String {
				continue
			}
			value := constant.StringVal(c.Val())
			if !utf8.ValidString(value) {
				return nil, fmt.Errorf("%s.%s has an invalid UTF-8 string value", t, id)
			}
			if seen[value] {
				continue
			}
			seen[value] = true
			m.Cases[id] = value
			fmt.Fprintf(&src, "  | %s\n", leanIdent(id))
		}
		if len(m.Cases) == 0 {
			return nil, fmt.Errorf("model %s requires string constants of its type", t)
		}
	default:
		return nil, fmt.Errorf("unsupported model type %s", t)
	}
	fmt.Fprintf(&src, "end %s\n", ns)
	m.Source = src.String()
	b.done[key] = m
	b.ordered = append(b.ordered, m)
	return m, nil
}

func isBigInt(t types.Type) bool {
	p, ok := types.Unalias(t).(*types.Pointer)
	if !ok {
		return false
	}
	n, ok := types.Unalias(p.Elem()).(*types.Named)
	return ok && n.Obj().Pkg() != nil && n.Obj().Pkg().Path() == "math/big" && n.Obj().Name() == "Int"
}

var leanBasics = map[string]string{
	"int": "Int64", "int8": "Int8", "int16": "Int16", "int32": "Int32", "int64": "Int64",
	"uint": "UInt64", "uint8": "UInt8", "uint16": "UInt16", "uint32": "UInt32", "uint64": "UInt64",
	"byte": "UInt8", "float64": "Float", "float32": "Float32", "bool": "Bool", "string": "String", "rune": "Char",
}

func (b *modelBuilder) fieldType(t types.Type, asNat bool) (lean, goShape string, err error) {
	if isBigInt(t) {
		if asNat {
			return "Nat", "", nil
		}
		return "Int", "", nil
	}
	switch v := types.Unalias(t).(type) {
	case *types.Basic:
		if b.plain && v.Kind() == types.Int32 {
			return "Int32", "", nil
		}
		if lean := leanBasics[v.Name()]; lean != "" {
			switch v.Kind() {
			case types.Int, types.Uint:
				return lean, v.Name(), nil
			default:
				return lean, "", nil
			}
		}
	case *types.Slice:
		if basic, ok := types.Unalias(v.Elem()).(*types.Basic); ok && basic.Kind() == types.Uint8 && !b.plain {
			return "ByteArray", "", nil
		}
		lean, shape, err := b.fieldType(v.Elem(), false)
		return "(Array " + lean + ")", "[]" + shape, err
	case *types.Pointer:
		lean, shape, err := b.fieldType(v.Elem(), false)
		return "(Option " + lean + ")", "*" + shape, err
	case *types.Named:
		m, err := b.add(v)
		if err != nil {
			return "", "", err
		}
		ns := strings.TrimSuffix(m.Lean, "."+m.Name)
		return ns + "." + leanIdent(m.Name), "", nil
	}
	return "", "", fmt.Errorf("unsupported field type %s", t)
}

func fieldTags(tag string) (map[string]string, error) {
	raw, ok := reflect.StructTag(tag).Lookup("leanfran")
	if !ok {
		return nil, nil
	}
	result := make(map[string]string)
	for _, part := range strings.Split(raw, ",") {
		key, val, ok := strings.Cut(strings.TrimSpace(part), "=")
		integer, valid := new(big.Int).SetString(val, 10)
		if _, duplicate := result[key]; !ok || !valid || duplicate {
			return nil, fmt.Errorf("invalid leanfran tag %q", part)
		}
		result[key] = integer.String()
	}
	return result, nil
}

func constraint(field, lean, tag, value string) (suffix, expr string, err error) {
	field = leanIdent(field)
	switch tag {
	case "ge", "le":
		bound := value
		switch {
		case lean == "Nat":
			field = "Int.ofNat " + field
		case lean == "Int":
		case strings.HasPrefix(lean, "UInt"):
			field = "Int.ofNat " + field + ".toNat"
		case strings.HasPrefix(lean, "Int"):
			field += ".toInt"
		default:
			return "", "", fmt.Errorf("%s requires an integer field", tag)
		}
		if tag == "ge" {
			return "_ge", field + " ≥ " + bound, nil
		}
		return "_le", field + " ≤ " + bound, nil
	case "min_len":
		if lean == "String" && !strings.HasPrefix(value, "-") {
			return "_min_length", field + ".length ≥ " + value, nil
		}
		return "", "", fmt.Errorf("%s requires a string and a nonnegative length", tag)
	case "min_items":
		if (lean == "ByteArray" || strings.HasPrefix(lean, "(Array ")) && !strings.HasPrefix(value, "-") {
			return "_min_items", field + ".size ≥ " + value, nil
		}
		return "", "", fmt.Errorf("%s requires a slice and a nonnegative length", tag)
	default:
		return "", "", fmt.Errorf("unsupported leanfran tag %q", tag)
	}
}
