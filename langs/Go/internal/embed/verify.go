package embed

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"go/build"
	"go/format"
	"go/parser"
	"go/token"
	"go/types"
	"os"
	"path/filepath"
	"regexp"

	"github.com/conao3/leanfran-go/internal/verify"
	leanlib "github.com/conao3/leanfran-go/lean"
)

var goToolDirective = regexp.MustCompile(`(?m)^([ \t]*(?:tool[ \t]+)?"?)github\.com/conao3/leanfran-go/cmd/leanfran-go([" \t]*(?://[^\r\n]*)?\r?)$`)

func (p *project) functions() []*verify.Function {
	var models []*verify.Function
	for _, name := range sortedKeys(p.packages) {
		pkg := p.packages[name]
		models = append(models, verify.Discover(name, pkg.fset, pkg.files)...)
	}
	return models
}

func (p *project) typeModels(models []*verify.Function) error {
	i := &modelImporter{p: p, strict: true, errors: make(map[string]error), cache: make(map[string]*types.Package), info: make(map[string]*types.Info), active: make(map[string]bool)}
	for _, path := range sortedKeys(p.blocks) {
		b := p.blocks[path]
		for _, name := range generatedNames {
			file := filepath.Join(b.pkg.dir, name)
			f, err := parser.ParseFile(b.pkg.fset, file, nil, parser.SkipObjectResolution)
			if err != nil {
				return err
			}
			b.pkg.files = append(b.pkg.files, f)
		}
	}
	named := make(map[string]verify.NamedType)
	for _, path := range sortedKeys(p.blocks) {
		for _, item := range p.blocks[path].verifyTypes {
			key := item.Path + "." + item.Name
			if !named[key].Plain || item.Plain {
				named[key] = item
			}
		}
	}
	checkErrors := make(map[string]error)
	intBytes := hostIntBytes()
	for _, m := range models {
		if m.Err != nil {
			continue
		}
		if intBytes != 8 {
			m.Err = fmt.Errorf("%s: model verification requires a 64-bit Go target", m.Files.Position(m.Decl.Pos()))
			continue
		}
		if p.blocks[m.Spec] == nil {
			m.Err = fmt.Errorf("%s: no Lean block at %q", m.Files.Position(m.Decl.Pos()), m.Spec)
			continue
		}
		pkg := p.packages[m.Package]
		i.initBinary(pkg.fset)
		if _, ok := checkErrors[m.Package]; !ok {
			_, _, checkErrors[m.Package] = i.check(pkg)
		}
		if err := checkErrors[m.Package]; err != nil {
			m.Err = fmt.Errorf("%s: type checking %s: %w", m.Files.Position(m.Decl.Pos()), pkg.path, err)
		}
		m.Info = i.info[m.Package]
		m.Named = named
	}
	return nil
}

func hostIntBytes() int64 {
	if sizes := types.SizesFor("gc", build.Default.GOARCH); sizes != nil {
		return sizes.Sizeof(types.Typ[types.Int])
	}
	return 0
}

func (p *project) proofInputs() (string, error) {
	h := sha256.New()
	w := json.NewEncoder(h)
	if err := w.Encode([]any{leanlib.Source, hostIntBytes()}); err != nil {
		return "", err
	}
	for _, path := range sortedKeys(p.blocks) {
		if err := w.Encode(p.blocks[path].hash); err != nil {
			return "", err
		}
	}
	for _, name := range []string{"go.mod", "go.sum", configName} {
		data, err := readRegular(filepath.Join(p.root, name))
		if err != nil && !os.IsNotExist(err) {
			return "", err
		}
		if name == "go.mod" {
			data = goToolDirective.ReplaceAll(data, []byte("${1}github.com/conao3/leanfran-go/cmd/leanfran${2}"))
		}
		if err := w.Encode(data); err != nil {
			return "", err
		}
	}
	for _, pkg := range sortedKeys(p.packages) {
		if err := w.Encode(pkg); err != nil {
			return "", err
		}
		for _, file := range p.packages[pkg].files {
			var source bytes.Buffer
			if err := format.Node(&source, token.NewFileSet(), file); err != nil {
				return "", err
			}
			if err := w.Encode(source.String()); err != nil {
				return "", err
			}
		}
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
