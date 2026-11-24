package verify

import (
	"go/ast"
	"go/parser"
	"go/token"
	"go/types"
	"strings"
	"testing"
)

func testModel(t *testing.T, text string) *Definition {
	t.Helper()
	fs := token.NewFileSet()
	f, err := parser.ParseFile(fs, "model.go", "package fixture\n"+text, parser.ParseComments|parser.SkipObjectResolution)
	if err != nil {
		t.Fatal(err)
	}
	info := &types.Info{
		Types:      make(map[ast.Expr]types.TypeAndValue),
		Defs:       make(map[*ast.Ident]types.Object),
		Uses:       make(map[*ast.Ident]types.Object),
		Selections: make(map[*ast.SelectorExpr]*types.Selection),
	}
	cfg := types.Config{Sizes: types.SizesFor("gc", "amd64")}
	files := []*ast.File{f}
	if _, err := cfg.Check("fixture", fs, files, info); err != nil {
		t.Fatal(err)
	}
	models := Discover("fixture", fs, files)
	if len(models) != 1 {
		t.Fatalf("expected 1 model, got %d", len(models))
	}
	models[0].Info = info
	return Definitions(models)[0]
}

func TestRejectsUnsupportedGo(t *testing.T) {
	for _, tc := range []struct{ name, helper, signature string }{
		{"pointer", "", "(x *int64) int64 { return *x }"},
		{"map", "", "(x map[int64]int64) int64 { return x[0] }"},
		{"channel", "", "(x chan int64) int64 { return <-x }"},
		{"goroutine", "func work() {}", "() { go work() }"},
		{"defer", "func work() {}", "() { defer work() }"},
		{"recover", "", "() { _ = recover() }"},
		{"interface", "type reads interface{ Read() int64 }", "(x reads) int64 { return x.Read() }"},
		{"method", "type value string; func (v value) Text() string { return string(v) }", "(v value) string { return v.Text() }"},
		{"closure", "", "(n int64) int64 { return func() int64 { return n }() }"},
		{"generic", "", "[T any](x T) T { return x }"},
		{"goto", "", "() int64 { goto done; done: return 0 }"},
		{"label", "", "() { loop: for { break loop } }"},
		{"string range", "", "(text string) int { var n int; for range text { n++ }; return n }"},
		{"slice expression", "", "(a []int64) []int64 { return a[1:2] }"},
		{"slice input write", "", "(a []int64) { a[0] = 0 }"},
		{"slice escape then write", "", "() int64 { a := []int64{1}; b := a; a[0] = 2; return b[0] }"},
		{"global read", "var count int64", "() int64 { return count }"},
		{"global write", "var count int64", "() { count = 2 }"},
		{"built-in IO", "", "() { println(0) }"},
		{"fallthrough", "", "(n int64) int64 { switch n { case 0: fallthrough; default: return n } }"},
		{"invalid UTF-8", "", `() string { return "\xff" }`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			d := testModel(t, tc.helper+"\n//leanfran:model refines=spec\nfunc F"+tc.signature)
			if d.Err == nil || !strings.HasPrefix(d.Err.Error(), "model.go:") {
				t.Fatalf("expected positioned unextracted error, got %v", d.Err)
			}
		})
	}
}

func TestDirective(t *testing.T) {
	d := testModel(t, "//leanfran:model spec=fixture.test/spec requires=ordered refines=independent.spec ensures=range.ok:bounded\nfunc f(x int64) int64 { return x }")
	if d.Err != nil {
		t.Fatal(d.Err)
	}
	for _, text := range []string{"∀", "ordered", "«independent».«spec»", "«range».«ok»", "bounded"} {
		if !strings.Contains(d.Source, text) {
			t.Fatalf("generated source lacks %q: %s", text, d.Source)
		}
	}

	for _, directive := range []string{
		"refines=inc refines=inc",
		"ensures=refines:foo",
		"requires=precondition",
		"ensures=no-separator",
		"refines=foo invalid=bar",
	} {
		d := testModel(t, "//leanfran:model "+directive+"\nfunc f(n int64) int64 { return n }")
		if d.Err == nil || !strings.HasPrefix(d.Err.Error(), "model.go:2:") {
			t.Fatalf("%s: expected invalid directive with location, got %v", directive, d.Err)
		}
	}
}
