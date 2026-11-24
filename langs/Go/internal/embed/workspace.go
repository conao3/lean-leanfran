package embed

import (
	"encoding/json"
	"fmt"
	"go/format"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"

	"github.com/conao3/leanfran-go"
	"github.com/conao3/leanfran-go/internal/verify"
	leanlib "github.com/conao3/leanfran-go/lean"
)

const generatorVersion = leanfran.GeneratorVersion

type batchJob struct {
	Module      string   `json:"module"`
	Package     string   `json:"package"`
	GoPath      string   `json:"go_path"`
	OutputDir   string   `json:"output_dir"`
	TypeModules []string `json:"type_modules,omitempty"`
	Models      []*model `json:"models,omitempty"`
}

type origin struct {
	block *block
	lines int
}

var (
	toolchainPattern = regexp.MustCompile(`^leanprover/lean4:v([0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?)$`)
	leanVersion      = regexp.MustCompile(`^Lean \(version ([^, )]+)`)
	lakeVersion      = regexp.MustCompile(`\(Lean version ([^, )]+)\)`)
	leanDiagnostic   = regexp.MustCompile(`^(error|warning|info): .*?(LeanGoEmbed/B[0-9a-f]+\.lean):([0-9]+):([0-9]+): (.*)$`)
)

func command(dir, name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	return cmd
}

func checkVersions(dir, toolchain, compiler string) error {
	want := toolchainPattern.FindStringSubmatch(toolchain)
	if want == nil {
		return fmt.Errorf("unsupported lean-toolchain %q", toolchain)
	}
	for _, tool := range []struct {
		name    string
		pattern *regexp.Regexp
	}{{"lean", leanVersion}, {"lake", lakeVersion}} {
		output, err := command(dir, tool.name, "--version").Output()
		if err != nil {
			return fmt.Errorf("%s --version: %w", tool.name, processError(err))
		}
		match := tool.pattern.FindStringSubmatch(string(output))
		if match == nil || match[1] != want[1] {
			return fmt.Errorf("%s must match lean-toolchain (%s): %s", tool.name, want[1], strings.TrimSpace(string(output)))
		}
	}
	output, err := command(dir, compiler, "--generator-version").Output()
	if err != nil {
		return fmt.Errorf("%s --generator-version: %w", compiler, processError(err))
	}
	if got := strings.TrimSpace(string(output)); got != strconv.Itoa(generatorVersion) {
		return fmt.Errorf("compiler generator version %s, expected %d", got, generatorVersion)
	}
	return nil
}

func resolveCompiler(value string) (string, error) {
	if value == "" {
		value = os.Getenv("LEANFRAN_GO_CLI")
	}
	if value == "" {
		value = "leanfran-go"
	}
	path, err := exec.LookPath(value)
	if err != nil {
		return "", fmt.Errorf("find leanfran-go: %w", err)
	}
	return filepath.Abs(path)
}

func (p *project) generate(blocks []*block, work, stage, compiler string, stderr io.Writer) ([]change, error) {
	compiler, err := resolveCompiler(compiler)
	if err != nil {
		return nil, err
	}
	if err := writeIfChanged(filepath.Join(work, "lean-toolchain"), []byte(p.toolchain+"\n")); err != nil {
		return nil, err
	}
	if err := checkVersions(work, p.toolchain, compiler); err != nil {
		return nil, err
	}
	lakefile, err := makeLakefile(p.root, p.config.Require)
	if err != nil {
		return nil, err
	}
	if err := writeIfChanged(filepath.Join(work, "lakefile.toml"), []byte(lakefile)); err != nil {
		return nil, err
	}
	configured := filepath.Join(work, "configured.toml")
	prev, _ := os.ReadFile(configured)
	if _, err := os.Stat(filepath.Join(work, "lake-manifest.json")); err != nil || string(prev) != lakefile {
		output, err := command(work, "lake", "update").CombinedOutput()
		if err != nil {
			return nil, fmt.Errorf("lake update: %w\n%s", err, output)
		}
		if err := writeIfChanged(configured, []byte(lakefile)); err != nil {
			return nil, err
		}
	}
	if err := writeVerificationModule(work, "LeanGoLib.Go", leanlib.Source); err != nil {
		return nil, err
	}
	origins, jobs, err := writeModules(work, stage, blocks, p)
	if err != nil {
		return nil, err
	}
	output, err := command(work, "lake", "build").CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("lake build: %w\n%s", err, mapDiagnostics(output, origins))
	}
	if diagnostics := mapDiagnostics(output, origins); diagnostics != string(output) {
		if _, err := io.WriteString(stderr, diagnostics); err != nil {
			return nil, err
		}
	}
	data, err := json.Marshal(jobs)
	if err != nil {
		return nil, err
	}
	batch := filepath.Join(stage, "batch.json")
	if err := os.WriteFile(batch, data, 0o600); err != nil {
		return nil, err
	}
	output, err = command(work, "lake", "env", compiler, "module", "generate", "--batch", batch, "--output", "json").Output()
	if err != nil {
		return nil, fmt.Errorf("leanfran-go: %w\n%s", processError(err), output)
	}

	var summaries []struct {
		Module    string
		Functions map[string]string
		Types     []verify.NamedType
	}
	if err := json.Unmarshal(output, &summaries); err != nil || len(summaries) != len(blocks) {
		return nil, fmt.Errorf("invalid leanfran-go batch result: %s", output)
	}
	var changes []change
	for i, b := range blocks {
		if summaries[i].Module != b.module {
			return nil, fmt.Errorf("invalid leanfran-go batch module %q", summaries[i].Module)
		}
		b.wrappers = summaries[i].Functions
		b.verifyTypes = summaries[i].Types
		for j := range b.verifyTypes {
			b.verifyTypes[j].Module = b.module
		}
		m := manifest{Block: b.pkg.path, Hash: b.hash, Generator: generatorVersion, Files: generatedNames}
		for _, name := range m.Files {
			data, err := os.ReadFile(filepath.Join(jobs[i].OutputDir, name))
			if err != nil {
				return nil, err
			}
			formatted, err := format.Source(data)
			if err != nil {
				return nil, b.errorf("format %s: %v", name, err)
			}
			changes = append(changes, change{path: filepath.Join(b.pkg.dir, name), data: formatted})
		}
		data, err := json.MarshalIndent(m, "", "  ")
		if err != nil {
			return nil, err
		}
		changes = append(changes, change{path: filepath.Join(b.pkg.dir, manifestName), data: append(data, '\n')})
	}
	return changes, nil
}

func writeModules(work, stage string, blocks []*block, p *project) (map[string]origin, []batchJob, error) {
	dir := filepath.Join(work, "LeanGoEmbed")
	if err := mkdir(dir); err != nil {
		return nil, nil, err
	}
	var aggregate strings.Builder
	var modelSource strings.Builder
	modelSource.WriteString("set_option warningAsError true\n")
	emitted := make(map[string]bool)
	origins := make(map[string]origin)
	var jobs []batchJob
	for _, b := range blocks {
		var header strings.Builder
		imports := slices.Clone(b.imports)
		for _, use := range b.uses {
			imports = append(imports, p.blocks[use].module)
		}
		job := batchJob{
			Module: b.module, Package: b.pkg.name, GoPath: b.pkg.path,
			OutputDir: filepath.Join(stage, strconv.Itoa(len(jobs))),
		}
		job.Models = slices.Clone(b.models)
		for _, dep := range b.deps {
			job.TypeModules = append(job.TypeModules, dep.module+"="+dep.pkg.path)
			for _, m := range dep.models {
				if !slices.Contains(job.Models, m) {
					job.Models = append(job.Models, m)
				}
			}
		}
		if len(job.Models) > 0 {
			imports = append(imports, "LeanGoModels")
		}
		for _, name := range imports {
			fmt.Fprintf(&header, "import %s\n", name)
		}
		fmt.Fprintf(&header, "set_option warningAsError true\n\nnamespace %s\n", b.module)
		for _, use := range b.uses {
			fmt.Fprintf(&header, "open %s\n", p.blocks[use].module)
		}
		plainNames := make(map[string]int)
		for _, m := range b.models {
			if m.Plain {
				plainNames[m.Name]++
			}
		}
		for _, m := range b.models {
			namespace, name, _ := strings.Cut(m.Lean, ".")
			prefix, _, _ := strings.Cut(name, ".")
			if !m.Plain {
				fmt.Fprintf(&header, "open %s.%s (%s)\n", namespace, prefix, leanIdent(strings.TrimPrefix(name, prefix+".")))
			} else if plainNames[m.Name] == 1 {
				fmt.Fprintf(&header, "namespace GoValues\nabbrev %s := %s.%s.%s\nend GoValues\n",
					leanIdent(m.Name), namespace, prefix, leanIdent(m.Name))
			}
			if !emitted[m.Lean] {
				modelSource.WriteString(m.Source)
				emitted[m.Lean] = true
			}
		}
		fmt.Fprintln(&header)
		path := strings.ReplaceAll(b.module, ".", "/") + ".lean"
		origins[path] = origin{b, strings.Count(header.String(), "\n")}
		body := header.String() + b.source.text + "\n\nend " + b.module + "\n"
		if err := writeIfChanged(filepath.Join(work, path), []byte(body)); err != nil {
			return nil, nil, err
		}
		fmt.Fprintf(&aggregate, "import %s\n", b.module)
		jobs = append(jobs, job)
	}
	for _, out := range []struct{ name, body string }{
		{"LeanGoEmbed.lean", aggregate.String()},
		{"LeanGoModels.lean", modelSource.String()},
	} {
		if err := writeIfChanged(filepath.Join(work, out.name), []byte(out.body)); err != nil {
			return nil, nil, err
		}
	}
	return origins, jobs, nil
}

func mapDiagnostics(data []byte, origins map[string]origin) string {
	lines := strings.Split(string(data), "\n")
	for i, line := range lines {
		m := leanDiagnostic.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		o, ok := origins[m[2]]
		if !ok {
			continue
		}
		row, _ := strconv.Atoi(m[3])
		col, _ := strconv.Atoi(m[4])
		row -= o.lines
		location := o.block.pos.String()
		if row > 0 {
			src := o.block.source
			line, column := src.location(row, col)
			location = fmt.Sprintf("%s:%d:%d", src.file, line, column)
		}
		lines[i] = fmt.Sprintf("%s: %s: (lean block %s, Lean %d:%d) %s",
			location, m[1], o.block.pkg.path, row, col, m[5])
	}
	return strings.Join(lines, "\n")
}
