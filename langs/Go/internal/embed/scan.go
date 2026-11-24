package embed

import (
	"fmt"
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
)

var leanModule = regexp.MustCompile(`^[A-Za-z_][A-Za-z_0-9']*(\.[A-Za-z_][A-Za-z_0-9']*)*$`)

func (p *project) scan() error {
	roots := p.config.Paths
	if len(roots) == 0 {
		roots = []string{"."}
	}
	var dirs []string
	for _, root := range roots {
		dir, err := resolveWithin(p.root, root)
		if err != nil {
			return fmt.Errorf("%s paths: %w", configName, err)
		}
		if info, err := os.Stat(dir); err != nil || !info.IsDir() {
			return fmt.Errorf("%s paths: expected a directory: %s", configName, root)
		}
		dirs = append(dirs, dir)
	}
	return filepath.WalkDir(p.root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil || !entry.IsDir() {
			return walkErr
		}
		if path != p.root {
			name := entry.Name()
			if name == "vendor" || name == "testdata" || strings.HasPrefix(name, ".") || strings.HasPrefix(name, "_") {
				return filepath.SkipDir
			}
			_, err := os.Stat(filepath.Join(path, "go.mod"))
			if err == nil {
				return filepath.SkipDir
			}
			if !os.IsNotExist(err) {
				return err
			}
		}
		p.dirs = append(p.dirs, path)
		for _, dir := range dirs {
			rel, err := filepath.Rel(dir, path)
			if err == nil && filepath.IsLocal(rel) {
				return p.scanPackage(path)
			}
		}
		return nil
	})
}

func (p *project) packagePath(dir string) (string, error) {
	rel, err := filepath.Rel(p.root, dir)
	if err != nil {
		return "", err
	}
	if rel == "." {
		return p.module, nil
	}
	return p.module + "/" + filepath.ToSlash(rel), nil
}

func (p *project) scanPackage(dir string) error {
	path, err := p.packagePath(dir)
	if err != nil {
		return err
	}
	pkg := &goPackage{dir: dir, path: path, fset: token.NewFileSet()}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || !strings.HasSuffix(name, ".go") || strings.HasSuffix(name, "_test.go") {
			continue
		}
		match, err := build.Default.MatchFile(dir, name)
		if err != nil {
			return err
		}
		if !match {
			continue
		}
		file := filepath.Join(dir, name)
		data, err := os.ReadFile(file)
		if err != nil {
			return err
		}
		if isGenerated(data) {
			continue
		}
		f, err := parser.ParseFile(pkg.fset, file, data, parser.SkipObjectResolution|parser.ParseComments)
		if err != nil {
			return err
		}
		if pkg.name != "" && pkg.name != f.Name.Name {
			return fmt.Errorf("%s: found packages %s and %s", dir, pkg.name, f.Name.Name)
		}
		pkg.name = f.Name.Name
		pkg.files = append(pkg.files, f)
		if err := p.scanFile(pkg, f, string(data)); err != nil {
			return err
		}
	}
	if pkg.name != "" {
		p.packages[path] = pkg
	}
	return nil
}

func (p *project) scanFile(pkg *goPackage, f *ast.File, data string) error {
	for _, spec := range f.Imports {
		path, err := strconv.Unquote(spec.Path.Value)
		if err != nil {
			return err
		}
		if path != runtimePath {
			continue
		}
		alias := "leanfran"
		if spec.Name != nil {
			alias = spec.Name.Name
		}
		if alias == "_" || alias == "." {
			return nil
		}
		for _, decl := range f.Decls {
			vars, ok := decl.(*ast.GenDecl)
			if !ok || vars.Tok != token.VAR {
				continue
			}
			for _, node := range vars.Specs {
				v := node.(*ast.ValueSpec)
				if len(v.Names) != 1 || v.Names[0].Name != "_" || len(v.Values) != 1 {
					continue
				}
				call, name := qualifiedCall(v.Values[0], alias)
				if name != "Lean" && name != "LeanFile" {
					continue
				}
				pos := pkg.fset.PositionFor(call.Pos(), false)
				b := &block{pkg: pkg, pos: pos, module: moduleName(pkg.path)}
				if previous := p.blocks[pkg.path]; previous != nil {
					return b.errorf("duplicate block for %s (first at %s)", pkg.path, previous.pos)
				}
				if err := b.readCall(call, name, alias, data); err != nil {
					return err
				}
				p.blocks[pkg.path] = b
			}
		}
	}
	return nil
}

func qualifiedCall(expr ast.Expr, alias string) (*ast.CallExpr, string) {
	call, ok := expr.(*ast.CallExpr)
	if !ok {
		return nil, ""
	}
	sel, ok := call.Fun.(*ast.SelectorExpr)
	if !ok {
		return nil, ""
	}
	id, ok := sel.X.(*ast.Ident)
	if !ok || id.Name != alias {
		return nil, ""
	}
	return call, sel.Sel.Name
}

func stringLiteral(expr ast.Expr) (*ast.BasicLit, error) {
	lit, ok := expr.(*ast.BasicLit)
	if !ok || lit.Kind != token.STRING {
		return nil, fmt.Errorf("expected a string literal")
	}
	return lit, nil
}

func (b *block) readCall(call *ast.CallExpr, name, alias, data string) error {
	if len(call.Args) == 0 || call.Ellipsis.IsValid() {
		return b.errorf("%s expects a source literal and optional options", name)
	}
	lit, err := stringLiteral(call.Args[0])
	if err != nil {
		return b.errorf("%s: %v", name, err)
	}
	if name == "LeanFile" {
		filename, err := strconv.Unquote(lit.Value)
		if err != nil {
			return b.errorf("%v", err)
		}
		file, err := resolveWithin(b.pkg.dir, filename)
		if err != nil || filepath.Dir(file) != b.pkg.dir {
			return b.errorf("LeanFile requires a file in the package directory: %q", filename)
		}
		body, err := os.ReadFile(file)
		if err != nil {
			return b.errorf("%v", err)
		}
		b.source = source{text: string(body), original: string(body), file: file}
	} else {
		start := b.pkg.fset.PositionFor(lit.Pos(), false).Offset
		end := start + 1
		if lit.Value[0] == '`' {
			end += strings.IndexByte(data[end:], '`') + 1
		} else {
			end = start + len(lit.Value)
		}
		b.source, err = literal(data[start:end], b.pos.Filename, data, start)
		if err != nil {
			return b.errorf("%v", err)
		}
	}
	for _, expr := range call.Args[1:] {
		opt, name := qualifiedCall(expr, alias)
		if opt == nil || opt.Ellipsis.IsValid() {
			return b.errorf("expected a literal leanfran option")
		}
		switch name {
		case "Models":
			for _, expr := range opt.Args {
				switch expr.(type) {
				case *ast.CompositeLit, *ast.CallExpr:
					b.modelExprs = append(b.modelExprs, expr)
				default:
					return b.errorf("Models expects a struct literal or string type conversion")
				}
			}
		case "Imports", "Uses":
			for _, expr := range opt.Args {
				arg, err := stringLiteral(expr)
				if err != nil {
					return b.errorf("%s: %v", name, err)
				}
				value, err := strconv.Unquote(arg.Value)
				if err != nil {
					return b.errorf("%s: %v", name, err)
				}
				if name == "Imports" {
					if !leanModule.MatchString(value) {
						return b.errorf("invalid Lean module name %q", value)
					}
					if !slices.Contains(b.imports, value) {
						b.imports = append(b.imports, value)
					}
				} else if !slices.Contains(b.uses, value) {
					b.uses = append(b.uses, value)
				}
			}
		default:
			return b.errorf("unsupported option %q", name)
		}
	}
	return nil
}

func resolveWithin(root, name string) (string, error) {
	if !filepath.IsLocal(name) {
		return "", fmt.Errorf("expected a relative path within %s: %q", root, name)
	}
	path, err := filepath.EvalSymlinks(filepath.Join(root, name))
	if err != nil {
		return "", err
	}
	if rel, err := filepath.Rel(root, path); err != nil || !filepath.IsLocal(rel) {
		return "", fmt.Errorf("path leaves %s: %q", root, name)
	}
	return path, nil
}
