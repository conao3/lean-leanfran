package schematest

import (
	"bytes"
	"encoding/json"
	"os"
	"reflect"
	"testing"
)

func TestSchemas(t *testing.T) {
	tests := []struct {
		name string
		typ  interface {
			JSONSchema(string) (map[string]any, error)
		}
	}{
		{"schema", SchemaRecord{}},
		{"range", CheckedRange{}},
		{"mixed", TypedMixedNat{}},
	}
	decode := func(t *testing.T, data []byte) any {
		t.Helper()
		decoder := json.NewDecoder(bytes.NewReader(data))
		decoder.UseNumber()
		var doc any
		if err := decoder.Decode(&doc); err != nil {
			t.Fatal(err)
		}
		return doc
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			want, err := test.typ.JSONSchema("draft-2020-12")
			if err != nil {
				t.Fatal(err)
			}
			data, err := json.Marshal(want)
			if err != nil {
				t.Fatal(err)
			}
			path := test.name + "/" + test.name + ".schema.json"
			got, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(decode(t, got), decode(t, data)) {
				t.Errorf("C and Go schemas differ\nC:  %s\nGo: %s", got, data)
			}
		})
	}
}
