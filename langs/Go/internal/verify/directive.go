package verify

import (
	"encoding/hex"
	"fmt"
	"go/ast"
	"go/token"
	"go/types"
	"regexp"
	"strings"
)

const TestFile = "leanfran_model_test.go"

type Predicate struct {
	Label string
	Name  string
}

type NamedType struct {
	Path, Name, Lean string
	Module           string
	Fields           map[string]string
	Cases            map[string]string
	Invariants       bool
	Plain            bool
}

type Function struct {
	Package string
	Spec    string
	Needs   string
	Checks  []Predicate
	Decl    *ast.FuncDecl
	Files   *token.FileSet
	Info    *types.Info
	Named   map[string]NamedType
	Err     error
}

func ModelModule(path string) string {
	return "LeanGoModel.B" + hex.EncodeToString([]byte(path))
}

func (f *Function) Name() string {
	return ModelModule(f.Package) + "." + f.Decl.Name.Name
}

func (f *Function) problem(pos token.Pos, format string, args ...any) error {
	return fmt.Errorf("%s: %s", f.Files.PositionFor(pos, false), fmt.Sprintf(format, args...))
}

var dotted = regexp.MustCompile(`^[A-Za-z_][A-Za-z_0-9']*(\.[A-Za-z_][A-Za-z_0-9']*)*$`)

func Discover(path string, files *token.FileSet, decls []*ast.File) []*Function {
	var result []*Function
	for _, file := range decls {
		for _, decl := range file.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if !ok || fn.Doc == nil {
				continue
			}
			var model *Function
			for _, comment := range fn.Doc.List {
				fields := strings.Fields(comment.Text)
				if len(fields) == 0 || fields[0] != "//leanfran:model" {
					continue
				}
				if model != nil {
					model.Err = model.problem(comment.Pos(), "duplicate leanfran:model directive")
					continue
				}
				model = &Function{Package: path, Spec: path, Decl: fn, Files: files}
				if err := model.parse(fields[1:]); err != nil {
					model.Err = model.problem(comment.Pos(), "%v", err)
				} else if fn.Recv != nil {
					model.Err = model.problem(fn.Pos(), "models must be top-level functions")
				}
				result = append(result, model)
			}
		}
	}
	return result
}

func (f *Function) parse(fields []string) error {
	seen := make(map[string]bool)
	labels := map[string]bool{"refines": true}
	for _, field := range fields {
		key, value, ok := strings.Cut(field, "=")
		if !ok || value == "" || seen[key] {
			return fmt.Errorf("invalid or duplicate directive option %q", field)
		}
		seen[key] = true
		switch key {
		case "spec":
			f.Spec = value
		case "requires", "refines":
			if !dotted.MatchString(value) {
				return fmt.Errorf("invalid Lean name %q", value)
			}
			if key == "requires" {
				f.Needs = value
			} else {
				f.Checks = append(f.Checks, Predicate{key, value})
			}
		case "ensures":
			for _, item := range strings.Split(value, ",") {
				label, name, _ := strings.Cut(item, ":")
				if !dotted.MatchString(label) || !dotted.MatchString(name) || labels[label] {
					return fmt.Errorf("invalid or duplicate ensures entry %q", item)
				}
				labels[label] = true
				f.Checks = append(f.Checks, Predicate{label, name})
			}
		default:
			return fmt.Errorf("unknown directive option %q", key)
		}
	}
	if len(f.Checks) == 0 {
		return fmt.Errorf("model requires refines or ensures")
	}
	return nil
}
