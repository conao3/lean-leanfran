package embed

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"go/build"
	"go/format"
	"go/parser"
	"go/token"
	"go/types"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/conao3/leanfran-go/internal/verify"
	leanlib "github.com/conao3/leanfran-go/lean"
)

const proofLock = "leanfran.lock"

var goToolDirective = regexp.MustCompile(`(?m)^([ \t]*(?:tool[ \t]+)?"?)github\.com/conao3/leanfran-go/cmd/leanfran-go([" \t]*(?://[^\r\n]*)?\r?)$`)

type obligation struct {
	Model  string   `json:"model"`
	Label  string   `json:"label"`
	State  string   `json:"status,omitempty"`
	Detail string   `json:"detail,omitempty"`
	Axioms []string `json:"axioms,omitempty"`
	File   string   `json:"file,omitempty"`
	Line   int      `json:"line,omitempty"`
}

type proofResults struct {
	Version int          `json:"version"`
	Hash    string       `json:"hash"`
	Results []obligation `json:"obligations"`
}

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

func (p *project) proofSources() (map[string]string, error) {
	dir := filepath.Join(p.root, "lean", "Proofs")
	modules := make(map[string]string)
	err := filepath.WalkDir(dir, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			if path == dir && os.IsNotExist(err) {
				return nil
			}
			return err
		}
		if entry.IsDir() || filepath.Ext(path) != ".lean" {
			return nil
		}
		rel, err := filepath.Rel(dir, path)
		if err != nil {
			return err
		}
		mod := "Proofs." + strings.ReplaceAll(filepath.ToSlash(strings.TrimSuffix(rel, ".lean")), "/", ".")
		if !leanModule.MatchString(mod) {
			return fmt.Errorf("%s: invalid proof module name", path)
		}
		data, err := readRegular(path)
		if err != nil {
			return err
		}
		modules[mod] = string(data)
		return nil
	})
	return modules, err
}

func hostIntBytes() int64 {
	if sizes := types.SizesFor("gc", build.Default.GOARCH); sizes != nil {
		return sizes.Sizeof(types.Typ[types.Int])
	}
	return 0
}

func (p *project) proofHash(proofs map[string]string) (string, error) {
	h := sha256.New()
	w := json.NewEncoder(h)
	if err := w.Encode([]any{generatorVersion, leanlib.Source, p.toolchain, hostIntBytes(), proofs}); err != nil {
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

func eachObligation(models []*verify.Function, f func(*verify.Function, string)) {
	for _, m := range models {
		if len(m.Checks) == 0 {
			f(m, "model")
		}
		for _, pred := range m.Checks {
			f(m, pred.Label)
		}
	}
}

func reportObligation(out io.Writer, o obligation) error {
	name := o.Model
	if i := strings.LastIndexByte(name, '.'); i != -1 {
		const prefix = "LeanGoModel.B"
		if path, err := hex.DecodeString(strings.TrimPrefix(name[:i], prefix)); err == nil {
			name = string(path) + "." + name[i+1:]
		}
	}
	_, err := fmt.Fprintf(out, "%s [%s]: %s\n", name, o.Label, o.State)
	return err
}

func (p *project) proofStatus(models []*verify.Function, out io.Writer) error {
	proofFile := filepath.Join(p.root, proofLock)
	data, err := readRegular(proofFile)
	if len(models) == 0 && os.IsNotExist(err) {
		return nil
	}
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	proofs, err := p.proofSources()
	if err != nil {
		return err
	}
	hash, err := p.proofHash(proofs)
	if err != nil {
		return err
	}
	var saved proofResults
	fresh := json.Unmarshal(data, &saved) == nil && saved.Version == 1 && saved.Hash == hash
	if fresh {
		for _, o := range saved.Results {
			if err := reportObligation(out, o); err != nil {
				return err
			}
		}
		return nil
	}
	var printed error
	eachObligation(models, func(m *verify.Function, label string) {
		printed = errors.Join(printed, reportObligation(out, obligation{Model: m.Name(), Label: label, State: "stale"}))
	})
	return errors.Join(printed, errors.New("obligation results are out of date"))
}

func writeVerificationModule(dir, name, source string) error {
	path := filepath.Join(dir, strings.ReplaceAll(name, ".", "/")+".lean")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return writeIfChanged(path, []byte(source))
}

func (p *project) checkProofs(work, compiler string, models []*verify.Function, require, verbose bool, out, diagnostics io.Writer) error {
	path := filepath.Join(p.root, proofLock)
	if len(models) == 0 {
		if _, err := os.Lstat(path); os.IsNotExist(err) {
			return nil
		}
	}
	proofs, err := p.proofSources()
	if err != nil {
		return err
	}
	hash, err := p.proofHash(proofs)
	if err != nil {
		return err
	}
	saved := proofResults{Version: 1, Hash: hash, Results: []obligation{}}
	if len(models) > 0 {
		if err := p.typeModels(models); err != nil {
			return err
		}
		if len(p.blocks) == 0 {
			eachObligation(models, func(m *verify.Function, label string) {
				detail := m.Err
				if detail == nil {
					detail = fmt.Errorf("%s: no Lean block at %q", m.Files.Position(m.Decl.Pos()), m.Spec)
				}
				_, _ = fmt.Fprintln(diagnostics, detail)
				saved.Results = append(saved.Results, obligation{Model: m.Name(), Label: label, State: "unextracted", Detail: detail.Error()})
			})
		} else {
			saved.Results, err = runProofs(work, compiler, verify.Definitions(models), proofs, verbose, diagnostics)
			if err != nil {
				return err
			}
		}
	}
	data, err := json.MarshalIndent(saved, "", "  ")
	if err != nil {
		return err
	}
	if err := writeIfChanged(path, append(data, '\n')); err != nil {
		return err
	}
	var failed bool
	for _, o := range saved.Results {
		if err := reportObligation(out, o); err != nil {
			return err
		}
		failed = failed || o.State == "unextracted" || o.State == "failed" || require && o.State != "proved"
	}
	if failed {
		return fmt.Errorf("model obligations did not pass check")
	}
	return nil
}

func runProofs(work, compiler string, defs []*verify.Definition, proofs map[string]string, verbose bool, diag io.Writer) ([]obligation, error) {
	dir := filepath.Join(work, "verification")
	for _, path := range []string{
		dir,
		filepath.Join(work, ".lake", "build", "lib", "lean", "Proofs"),
		filepath.Join(work, ".lake", "build", "lib", "lean", "LeanGoModel"),
	} {
		if err := os.RemoveAll(path); err != nil {
			return nil, err
		}
	}
	var results []obligation
	var refs []obligation
	built := make(map[string]bool)
	results = make([]obligation, 0, len(defs))
	packages := make(map[string][]string)
	for _, d := range defs {
		model := d.Model
		err := d.Err
		if err == nil {
			imports := append([]string{"LeanGoLib.Go", moduleName(model.Spec)}, d.TypeImports...)
			for _, mod := range d.Imports {
				if !built[mod] {
					err = fmt.Errorf("%s: cannot elaborate dependency %s", model.Files.Position(model.Decl.Pos()), mod)
					break
				}
				imports = append(imports, mod)
			}
			if err == nil {
				var source strings.Builder
				for _, mod := range imports {
					fmt.Fprintf(&source, "import %s\n", mod)
				}
				source.WriteString("\n" + d.Source)
				if err := writeVerificationModule(dir, d.Module(), source.String()); err != nil {
					return nil, err
				}
				output, buildErr := lakeOutput(work, verbose, "build", "+"+d.Module())
				if buildErr != nil || verbose {
					_, _ = io.WriteString(diag, output)
				}
				if buildErr != nil {
					err = fmt.Errorf("%s: could not elaborate translated definition or spec", model.Files.Position(model.Decl.Pos()))
				} else {
					built[d.Module()] = true
					packages[verify.ModelModule(model.Package)] = append(packages[verify.ModelModule(model.Package)], d.Module())
				}
			}
		}
		if err != nil {
			_, _ = fmt.Fprintln(diag, err)
		}
		eachObligation([]*verify.Function{model}, func(m *verify.Function, label string) {
			o := obligation{Model: m.Name(), Label: label}
			if err != nil {
				o.State, o.Detail = "unextracted", err.Error()
				results = append(results, o)
			} else {
				refs = append(refs, o)
			}
		})
	}
	for _, pkg := range sortedKeys(packages) {
		source := "import " + strings.Join(packages[pkg], "\nimport ") + "\n"
		if err := writeVerificationModule(dir, pkg, source); err != nil {
			return nil, err
		}
	}
	for _, mod := range sortedKeys(proofs) {
		if err := writeVerificationModule(dir, mod, proofs[mod]); err != nil {
			return nil, err
		}
	}
	var failed []string
	proofPaths := strings.NewReplacer(
		filepath.Join(work, "verification", "Proofs")+string(filepath.Separator), "lean/Proofs/",
		"verification/Proofs/", "lean/Proofs/",
	)
	for _, mod := range sortedKeys(proofs) {
		output, err := lakeOutput(work, verbose, "build", "+"+mod)
		if err != nil || verbose {
			_, _ = io.WriteString(diag, proofPaths.Replace(output))
		}
		if err != nil {
			failed = append(failed, proofs[mod])
		} else {
			built[mod] = true
		}
	}
	if len(refs) > 0 {
		checked, err := queryProofs(work, compiler, sortedKeys(built), refs, diag)
		if err != nil {
			return nil, err
		}
		for _, o := range checked {
			if strings.HasPrefix(o.File, "Proofs/") {
				o.File = "lean/" + o.File
			}
			if o.State == "missing" && failedProof(o, failed) {
				o.State = "failed"
			}
			results = append(results, o)
		}
	}
	slices.SortFunc(results, func(a, b obligation) int {
		if a.Model == b.Model {
			return strings.Compare(a.Label, b.Label)
		}
		return strings.Compare(a.Model, b.Model)
	})
	return results, nil
}

func queryProofs(work, compiler string, modules []string, refs []obligation, diag io.Writer) ([]obligation, error) {
	path := filepath.Join(work, "verification", "obligations.json")
	data, err := json.Marshal(refs)
	if err != nil {
		return nil, err
	}
	if err := writeIfChanged(path, data); err != nil {
		return nil, err
	}
	args := append([]string{"env", compiler, "--lang", "go", "obligations", "check", "--modules"}, modules...)
	args = append(args, "--obligations", path)
	cmd := command(work, "lake", args...)
	cmd.Stderr = diag
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("leanfran --lang go obligations check: %w", err)
	}
	var checked []obligation
	if err := json.Unmarshal(output, &checked); err != nil || len(checked) != len(refs) {
		return nil, fmt.Errorf("invalid obligations check response: %s", output)
	}
	for i, o := range checked {
		if o.Model != refs[i].Model || o.Label != refs[i].Label || o.State == "" {
			return nil, fmt.Errorf("unexpected obligation result at index %d", i)
		}
	}
	return checked, nil
}

func failedProof(o obligation, sources []string) bool {
	fn := o.Model[strings.LastIndexByte(o.Model, '.')+1:]
	name := regexp.QuoteMeta(fn + ".proof." + o.Label)
	pattern := regexp.MustCompile(`\b(?:theorem|lemma|def)\s+(?:[^\s:]+\.)?` + name + `(?:\s|:|$)`)
	for _, source := range sources {
		if pattern.MatchString(strings.NewReplacer("«", "", "»", "").Replace(source)) {
			return true
		}
	}
	return false
}
