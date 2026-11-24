package embed

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"slices"
	"strings"
)

func makeLakefile(root string, requirements []map[string]any) (string, error) {
	var out strings.Builder
	out.WriteString(`name = "leanfran-go-workspace"
defaultTargets = ["LeanGoEmbed", "LeanGoModels"]

[[lean_lib]]
name = "LeanGoEmbed"

[[lean_lib]]
name = "LeanGoModels"

[[lean_lib]]
name = "LeanGoLib"

[[lean_lib]]
name = "LeanGoModel"
srcDir = "verification"

[[lean_lib]]
name = "Proofs"
srcDir = "verification"
`)
	for _, require := range requirements {
		out.WriteString("\n[[require]]\n")
		for _, key := range sortedKeys(require) {
			v := require[key]
			if path, ok := v.(string); key == "path" && ok && !filepath.IsAbs(path) {
				v = filepath.Join(root, path)
			}
			encoded, err := toml(v)
			if err != nil {
				return "", fmt.Errorf("%s require.%s: %w", configName, key, err)
			}
			fmt.Fprintf(&out, "%s = %s\n", quote(key), encoded)
		}
	}
	return out.String(), nil
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	return keys
}

func quote(s string) string {
	data, _ := json.Marshal(s)
	return string(data)
}

func toml(value any) (string, error) {
	switch v := value.(type) {
	case string:
		return quote(v), nil
	case bool, json.Number:
		return fmt.Sprint(v), nil
	case []any:
		var parts []string
		for _, item := range v {
			s, err := toml(item)
			if err != nil {
				return "", err
			}
			parts = append(parts, s)
		}
		return "[" + strings.Join(parts, ", ") + "]", nil
	case map[string]any:
		var parts []string
		for _, key := range sortedKeys(v) {
			s, err := toml(v[key])
			if err != nil {
				return "", err
			}
			parts = append(parts, quote(key)+" = "+s)
		}
		return "{ " + strings.Join(parts, ", ") + " }", nil
	default:
		return "", fmt.Errorf("unsupported TOML value %v", value)
	}
}
