package embed

import (
	"go/token"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func scannerProject(t *testing.T, files map[string]string) *project {
	t.Helper()
	p := &project{
		root: t.TempDir(), module: "example.com/test", toolchain: defaultToolchain,
		blocks: make(map[string]*block), packages: make(map[string]*goPackage),
	}
	for name, data := range files {
		path := filepath.Join(p.root, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(data), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return p
}

func TestScan(t *testing.T) {
	const raw = "package raw\r\nimport lf \"github.com/conao3/leanfran-go\"\r\nvar _ = lf.Lean(`\r\ndef café := 2\r\n`, lf.Imports(\"Std.Data.HashMap\"))\r\n"
	const interpreted = "package text\nimport \"github.com/conao3/leanfran-go\"\nvar _ = leanfran.Lean(\"def x := 1\\ndef y := \\u732b\")\n"
	p := scannerProject(t, map[string]string{
		"raw/raw.go":      raw,
		"raw/helper.go":   "package raw\nvar X = 1\n",
		"raw/raw_test.go": raw,
		"text/text.go":    interpreted,
		"file/file.go":    "package file\nimport \"github.com/conao3/leanfran-go\"\nvar _ = leanfran.LeanFile(\"code.lean\")\n",
		"file/code.lean":  "def 漢 := ?\n",
		"other/other.go":  "package other\nimport leanfran \"example.org/other\"\nvar _ = leanfran.Lean(x + y)\n",
	})
	if err := p.scan(); err != nil {
		t.Fatal(err)
	}
	for _, tt := range []struct {
		name, file, text  string
		row, column       int
		wantLine, wantCol int
	}{
		{"raw", "raw.go", "\ndef café := 2\n", 2, 9, 4, 11},
		{"text", "text.go", "def x := 1\ndef y := 猫", 2, 9, 3, strings.Index(strings.Split(interpreted, "\n")[2], `\u732b`) + 1},
		{"file", "code.lean", "def 漢 := ?\n", 1, 9, 1, 12},
	} {
		t.Run(tt.name, func(t *testing.T) {
			b := p.blocks[p.module+"/"+tt.name]
			if b == nil || b.source.text != tt.text || filepath.Base(b.source.file) != tt.file {
				t.Fatalf("unexpected block: %+v", b)
			}
			line, col := b.source.location(tt.row, tt.column)
			if line != tt.wantLine || col != tt.wantCol {
				t.Fatalf("mapped position %d:%d, expected %d:%d", line, col, tt.wantLine, tt.wantCol)
			}
		})
	}
	if len(p.blocks) != 3 || len(p.packages[p.module+"/raw"].files) != 2 {
		t.Fatalf("expected three blocks and two production files in raw")
	}
}

func TestScanErrors(t *testing.T) {
	const header = "package input\nimport \"github.com/conao3/leanfran-go\"\n"
	for _, tt := range []struct{ name, first, second, want string }{
		{"concat", "var _ = leanfran.Lean(\"def x := \" + \"1\")", "", "expected a string literal"},
		{"duplicate", "var _ = leanfran.Lean(\"\")", "var _ = leanfran.Lean(\"\")", "duplicate block"},
		{"missing-file", "var _ = leanfran.LeanFile(\"../elsewhere.lean\")", "", "requires a file in the package directory"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			files := map[string]string{"first.go": header + tt.first}
			if tt.second != "" {
				files["second.go"] = header + tt.second
			}
			p := scannerProject(t, files)
			if err := p.scan(); err == nil || !strings.Contains(err.Error(), tt.want) {
				t.Fatalf("scan returned %v", err)
			}
		})
	}
}

func TestUses(t *testing.T) {
	p := &project{blocks: make(map[string]*block)}
	for _, name := range []string{"a", "b", "c"} {
		p.blocks[name] = &block{pkg: &goPackage{path: name}, pos: token.Position{Filename: name + ".go", Line: 1, Column: 1}}
	}
	p.blocks["a"].uses = []string{"b"}
	p.blocks["b"].uses = []string{"c"}
	p.blocks["c"].uses = []string{"a"}
	if _, err := p.order(); err == nil || !strings.Contains(err.Error(), "cycle in Uses") {
		t.Fatalf("order returned %v", err)
	}
	p.blocks["c"].uses = []string{"unknown"}
	if _, err := p.order(); err == nil || !strings.Contains(err.Error(), "has no Lean block") {
		t.Fatalf("order returned %v", err)
	}
	p.blocks["c"].uses = nil
	order, err := p.order()
	if err != nil || len(order) != 3 || len(order[2].deps) != 2 || order[2].pkg.path != "a" {
		t.Fatalf("order returned %v, %v", order, err)
	}
}
