package kernel

import (
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"os/exec"
	"regexp"
	"slices"
	"testing"
)

func runtimeWrappers(t *testing.T) []string {
	file, err := parser.ParseFile(token.NewFileSet(), "leanfran_lean_gen.go", nil, 0)
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	for _, decl := range file.Decls {
		fn, ok := decl.(*ast.FuncDecl)
		if !ok || len(fn.Body.List) != 1 {
			continue
		}
		ret, ok := fn.Body.List[0].(*ast.ReturnStmt)
		if !ok || len(ret.Results) != 1 {
			continue
		}
		call, ok := ret.Results[0].(*ast.CallExpr)
		if !ok {
			continue
		}
		sel, ok := call.Fun.(*ast.SelectorExpr)
		if !ok {
			continue
		}
		if pkg, ok := sel.X.(*ast.Ident); !ok || pkg.Name != "rt" {
			continue
		}
		if !slices.ContainsFunc(call.Args, func(arg ast.Expr) bool { _, ok := arg.(*ast.Ident); return !ok }) {
			names = append(names, fn.Name.Name)
		}
	}
	return names
}

func TestRuntimeWrappersInline(t *testing.T) {
	if os.Getenv("LEANFRAN_ARRAY_COST") == "" {
		t.Skip("make test-array-cost sets LEANFRAN_ARRAY_COST")
	}
	wrappers := runtimeWrappers(t)
	for _, name := range []string{"l_Array_push", "l_String_getUTF8Byte", "l_UInt64_ofNat"} {
		if !slices.Contains(wrappers, name) {
			t.Fatalf("%s is not a one-call wrapper of rt", name)
		}
	}
	out, err := exec.Command("go", "build", "-gcflags=-m=2", "-o", os.DevNull, ".").CombinedOutput()
	if err != nil {
		t.Fatalf("go build -gcflags=-m=2: %v\n%s", err, out)
	}
	decision := regexp.MustCompile(`(?m)^\./leanfran_lean_gen\.go:\d+:\d+: (can|cannot) inline (l_\w+)(.*)$`)
	inlined := map[string]string{}
	for _, m := range decision.FindAllStringSubmatch(string(out), -1) {
		if m[1] == "cannot" {
			inlined[m[2]] = m[3]
		} else {
			inlined[m[2]] = ""
		}
	}
	for _, name := range wrappers {
		reason, ok := inlined[name]
		if !ok {
			t.Errorf("the compiler did not report on %s", name)
		} else if reason != "" {
			t.Errorf("%s does not inline%s", name, reason)
		}
	}
	t.Logf("checked %d one-call wrappers of rt", len(wrappers))
}
