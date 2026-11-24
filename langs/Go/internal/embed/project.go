package embed

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/token"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"

	"github.com/conao3/leanfran-go/internal/verify"
)

const (
	runtimePath      = "github.com/conao3/leanfran-go"
	defaultToolchain = "leanprover/lean4:v4.35.0"
	configName       = "leanfran.config.json"
	manifestName     = "leanfran.json"
)

type config struct {
	Paths   []string         `json:"paths"`
	Require []map[string]any `json:"require"`
}

type project struct {
	root, module, toolchain string
	config                  config
	blocks                  map[string]*block
	packages                map[string]*goPackage
	dirs                    []string
}

type goPackage struct {
	dir, name, path string
	fset            *token.FileSet
	files           []*ast.File
}

type block struct {
	pkg           *goPackage
	module        string
	pos           token.Position
	source        source
	imports, uses []string
	wrappers      map[string]string
	verifyTypes   []verify.NamedType
	modelExprs    []ast.Expr
	models        []*model
	deps          []*block
	hash          string
}

func (b *block) errorf(format string, args ...any) error {
	return fmt.Errorf("%s: %s", b.pos, fmt.Sprintf(format, args...))
}

func loadProject(dir string) (*project, error) {
	dir, err := filepath.Abs(dir)
	if err != nil {
		return nil, err
	}
	cmd := exec.Command("go", "list", "-m", "-json")
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GOWORK=off")
	data, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("find Go module at %s: %w", dir, processError(err))
	}
	var module struct{ Path, Dir string }
	if err := json.Unmarshal(data, &module); err != nil {
		return nil, err
	}
	if module.Path == "" || module.Dir == "" {
		return nil, fmt.Errorf("%s is outside a Go module", dir)
	}
	root, err := filepath.EvalSymlinks(module.Dir)
	if err != nil {
		return nil, err
	}
	p := &project{
		root: root, module: module.Path, toolchain: defaultToolchain,
		blocks: make(map[string]*block), packages: make(map[string]*goPackage),
	}
	if data, err := os.ReadFile(filepath.Join(root, configName)); err == nil {
		dec := json.NewDecoder(strings.NewReader(string(data)))
		dec.DisallowUnknownFields()
		dec.UseNumber()
		if err := dec.Decode(&p.config); err != nil {
			return nil, fmt.Errorf("%s: invalid configuration: %w", configName, err)
		}
		if !json.Valid(data) {
			return nil, fmt.Errorf("%s: trailing configuration data", configName)
		}
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	if data, err := os.ReadFile(filepath.Join(root, "lean-toolchain")); err == nil {
		p.toolchain = strings.TrimSpace(string(data))
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	return p, nil
}

func moduleName(path string) string {
	return "LeanGoEmbed.B" + hex.EncodeToString([]byte(path))
}

func processError(err error) error {
	if exit, ok := err.(*exec.ExitError); ok && len(exit.Stderr) > 0 {
		return fmt.Errorf("%w: %s", err, strings.TrimSpace(string(exit.Stderr)))
	}
	return err
}

func (p *project) order() ([]*block, error) {
	var names []string
	for name := range p.blocks {
		names = append(names, name)
	}
	slices.Sort(names)
	var ordered []*block
	active := make(map[string]bool)
	var visit func(*block) error
	visit = func(b *block) error {
		name := b.pkg.path
		if active[name] {
			return b.errorf("cycle in Uses at %s", name)
		}
		if b.hash != "" {
			return nil
		}
		active[name] = true
		var dependencies []string
		for _, use := range b.uses {
			dep := p.blocks[use]
			if dep == nil {
				return b.errorf("Uses %q has no Lean block", use)
			}
			if dep.pkg.name == "main" {
				return b.errorf("Uses %q refers to a command package", use)
			}
			if err := visit(dep); err != nil {
				return err
			}
			dependencies = append(dependencies, dep.hash)
			for _, candidate := range append([]*block{dep}, dep.deps...) {
				if !slices.Contains(b.deps, candidate) {
					b.deps = append(b.deps, candidate)
				}
			}
		}
		modelSources := make([]string, 0, len(b.models))
		for _, m := range b.models {
			modelSources = append(modelSources, m.Source)
		}
		values := []any{
			b.pkg.path, b.pkg.name, b.source.text, b.imports, b.uses, dependencies,
			b.models, modelSources, p.config, p.toolchain, generatorVersion,
		}
		data, err := json.Marshal(values)
		if err != nil {
			return err
		}
		b.hash = fmt.Sprintf("%x", sha256.Sum256(data))
		delete(active, name)
		ordered = append(ordered, b)
		return nil
	}
	for _, name := range names {
		if err := visit(p.blocks[name]); err != nil {
			return nil, err
		}
	}
	return ordered, nil
}
