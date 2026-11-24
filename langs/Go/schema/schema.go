package schema

import (
	"encoding/json"
	"fmt"
	"math/big"
	"strconv"
)

type document = map[string]any

type builder struct {
	target, defsKey string
	named           map[string]bool
	referenced      map[string]bool
	definitions     document
}

func JSONSchema(d *Desc, target string) (map[string]any, error) {
	b := builder{
		target: target, defsKey: "definitions",
		named: make(map[string]bool), referenced: make(map[string]bool), definitions: make(document),
	}
	switch target {
	case "draft-2020-12":
		b.defsKey = "$defs"
	case "draft-07", "openapi-3.0":
	default:
		return nil, fmt.Errorf("unsupported JSON Schema target %q", target)
	}
	result := b.generate(d)
	if len(b.definitions) > 0 {
		if target != "draft-2020-12" {
			result = document{"allOf": []document{result}}
		}
		result[b.defsKey] = b.definitions
	}
	switch target {
	case "draft-2020-12":
		result["$schema"] = "https://json-schema.org/draft/2020-12/schema"
	case "draft-07":
		result["$schema"] = "http://json-schema.org/draft-07/schema#"
	}
	return result, nil
}

func (b *builder) generate(d *Desc) document {
	d = d.resolve()
	switch d.dataKind() {
	case "nat":
		return document{"type": "integer", "minimum": 0}
	case "int":
		return document{"type": "integer"}
	case "uint", "usize":
		if d.Bits == 64 {
			return document{"type": "string", "pattern": "^(0|[1-9][0-9]*)$"}
		}
		return document{"type": "integer", "minimum": 0, "maximum": uint64(1)<<d.Bits - 1}
	case "sint", "isize":
		limit := new(big.Int).Lsh(big.NewInt(1), uint(d.Bits-1))
		lo := new(big.Int).Neg(limit)
		if d.Bits == 64 {
			return b.withBounds(document{"type": "integer", "minimum": schemaNumber(lo.String())}, map[string]string{"exclusiveMaximum": limit.String()})
		}
		return document{"type": "integer", "minimum": lo.Int64(), "maximum": limit.Int64() - 1}
	case "fin":
		return b.withBounds(document{"type": "integer", "minimum": 0}, map[string]string{"exclusiveMaximum": d.Bound})
	case "bool":
		return document{"type": "boolean"}
	case "string":
		return document{"type": "string"}
	case "char":
		return document{"type": "string", "minLength": 1, "maxLength": 1}
	case "float", "float32":
		return document{"type": "number"}
	case "unit":
		return document{"type": "object", "additionalProperties": false}
	case "bytes":
		return document{"type": "array", "items": document{"type": "integer", "minimum": 0, "maximum": 255}}
	case "list", "array":
		return document{"type": "array", "items": b.generate(d.First)}
	case "option":
		item := b.generate(d.First)
		if b.target != "openapi-3.0" {
			return document{"anyOf": []document{item, {"type": "null"}}}
		}
		if _, ok := item["type"]; !ok {
			item = document{"allOf": []document{item}}
		}
		item["nullable"] = true
		return item
	case "prod":
		return b.tuple([]document{b.generate(d.First), b.generate(d.Second)})
	case "except":
		return document{"oneOf": []document{tagged("ok", b.generate(d.Second)), tagged("error", b.generate(d.First))}}
	case "subtype":
		return b.withBounds(b.generate(d.First), d.Bounds)
	default:
		return b.namedType(d)
	}
}

func (b *builder) namedType(d *Desc) document {
	ref := document{"$ref": "#/" + b.defsKey + "/" + d.Name}
	if b.named[d.Name] {
		b.referenced[d.Name] = true
		return ref
	}
	if _, found := b.definitions[d.Name]; found {
		return ref
	}
	b.named[d.Name] = true
	var result document
	switch d.dataKind() {
	case "struct":
		result = b.fields(d.Variants[0])
	case "inductive":
		variants := make([]document, len(d.Variants))
		for i, variant := range d.Variants {
			variants[i] = b.variant(variant)
		}
		result = document{"oneOf": variants}
	case "enum":
		result = document{"type": "string", "enum": d.Cases}
	default:
		panic("unknown descriptor kind: " + d.Kind)
	}
	delete(b.named, d.Name)
	if b.referenced[d.Name] {
		b.definitions[d.Name] = result
		return ref
	}
	return result
}

func (b *builder) fields(v Variant) document {
	properties := make(document)
	required := []string{}
	b.recordFields(v, properties, &required)
	return record(properties, required)
}

func (b *builder) recordFields(v Variant, properties document, required *[]string) {
	for _, f := range v.Fields {
		d := f.Desc.resolve()
		if f.Flat {
			b.recordFields(d.Variants[0], properties, required)
			continue
		}
		properties[f.Key] = b.withBounds(b.generate(d), f.Bounds)
		if d.Kind != "option" {
			*required = append(*required, f.Key)
		}
	}
}

func (b *builder) variant(v Variant) document {
	if len(v.Fields) == 0 {
		if b.target == "openapi-3.0" {
			return document{"type": "string", "enum": []string{v.Name}}
		}
		return document{"const": v.Name}
	}
	if !v.Positional {
		return tagged(v.Name, b.fields(v))
	}
	items := make([]document, len(v.Fields))
	for i, f := range v.Fields {
		items[i] = b.withBounds(b.generate(f.Desc), f.Bounds)
	}
	if len(items) == 1 {
		return tagged(v.Name, items[0])
	}
	return tagged(v.Name, b.tuple(items))
}

func (b *builder) tuple(items []document) document {
	key := "items"
	if b.target == "draft-2020-12" {
		key = "prefixItems"
	}
	return document{"type": "array", key: items, "minItems": len(items), "maxItems": len(items)}
}

func (b *builder) withBounds(s document, bounds map[string]string) document {
	limited := make(document)
	for key, value := range bounds {
		if b.target == "openapi-3.0" {
			switch key {
			case "exclusiveMinimum":
				limited["minimum"] = schemaNumber(value)
				limited[key] = true
				continue
			case "exclusiveMaximum":
				limited["maximum"] = schemaNumber(value)
				limited[key] = true
				continue
			}
		}
		if _, exists := limited[key]; !exists {
			limited[key] = schemaNumber(value)
		}
	}
	for _, k := range []string{"$ref", "anyOf", "oneOf", "allOf"} {
		if _, exists := s[k]; exists && len(limited) > 0 {
			return document{"allOf": []document{s, limited}}
		}
	}
	for key, value := range limited {
		s[key] = value
	}
	return s
}

func record(properties document, required []string) document {
	return document{"type": "object", "properties": properties, "required": required, "additionalProperties": false}
}

func tagged(key string, payload document) document {
	return record(document{key: payload}, []string{key})
}

func schemaNumber(value string) any {
	if n, err := strconv.ParseInt(value, 10, 64); err == nil && n >= -(1<<53) && n <= 1<<53 {
		return n
	}
	if n, err := strconv.ParseFloat(value, 64); err == nil {
		return n
	}
	return json.Number(value)
}
