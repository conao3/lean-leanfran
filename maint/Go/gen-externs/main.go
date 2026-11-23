package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"log"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"unicode"
	"unicode/utf8"
)

func main() {
	if len(os.Args) != 2 {
		log.Fatal("usage: gen-externs <rt directory>")
	}
	dir := os.Args[1]
	files, err := filepath.Glob(filepath.Join(dir, "*.go"))
	if err != nil {
		log.Fatal(err)
	}
	names := make(map[string]struct{})
	for _, path := range files {
		if strings.HasSuffix(path, "_test.go") {
			continue
		}
		file, err := parser.ParseFile(token.NewFileSet(), path, nil, 0)
		if err != nil {
			log.Fatal(err)
		}
		if file.Name.Name != "rt" {
			log.Fatalf("%s: expected package rt", path)
		}
		for _, decl := range file.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if ok && fn.Recv == nil && fn.Name.IsExported() {
				first, size := utf8.DecodeRuneInString(fn.Name.Name)
				names[string(unicode.ToLower(first))+fn.Name.Name[size:]] = struct{}{}
			}
		}
	}
	sorted := make([]string, 0, len(names))
	for name := range names {
		sorted = append(sorted, name)
	}
	slices.Sort(sorted)
	fmt.Println("namespace LeanGo")
	fmt.Println()
	fmt.Println("def runtimeExterns : Array String := #[")
	for i, name := range sorted {
		separator := ","
		if i == len(sorted)-1 {
			separator = ""
		}
		fmt.Printf("  %q%s\n", name, separator)
	}
	fmt.Println("]")
	fmt.Println()
	fmt.Println("end LeanGo")
}
