package leanfran

import (
	"bytes"
	"encoding/json"
	"io"
	"unicode/utf8"

	"github.com/conao3/leanfran-go/rt"
	"github.com/conao3/leanfran-go/schema"
)

func MarshalJSON[T any](c Codec[T], value T, path ...any) ([]byte, error) {
	if err := Validate(c, value, path...); err != nil {
		return nil, err
	}
	v := c.ToLean(value)
	defer rt.Lean_dec(v)
	var out bytes.Buffer
	encoder := json.NewEncoder(&out)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(schema.Payload(c.Desc, v)); err != nil {
		return nil, err
	}
	return bytes.TrimSuffix(out.Bytes(), []byte{'\n'}), nil
}

func UnmarshalJSON[T any](c Codec[T], data []byte, path ...any) (T, error) {
	if !utf8.Valid(data) {
		return Zero[T](), &ValidationError{Issues: []Issue{{Message: "expected valid UTF-8", Path: path}}}
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.UseNumber()
	var raw any
	if err := decoder.Decode(&raw); err != nil {
		return Zero[T](), &ValidationError{Issues: []Issue{{Message: err.Error(), Path: path}}}
	}
	if decoder.Decode(new(any)) != io.EOF {
		return Zero[T](), &ValidationError{Issues: []Issue{{Message: "unexpected data after JSON value", Path: path}}}
	}
	var validation ValidationError
	v := schema.Parse(c.Desc, raw, validation.Add)
	defer rt.Lean_dec(v)
	validation.Prefix(0, path...)
	if err := validation.Err(); err != nil {
		return Zero[T](), err
	}
	out := c.FromLean(v)
	if err := Validate(c, out, path...); err != nil {
		return Zero[T](), err
	}
	return out, nil
}
