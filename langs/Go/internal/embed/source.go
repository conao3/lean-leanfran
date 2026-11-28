package embed

import (
	"strconv"
	"strings"
	"unicode/utf8"
)

type source struct {
	text, file, original string
	offsets              []int
}

func literal(raw, filename, file string, start int) (source, error) {
	value, err := strconv.Unquote(raw)
	if err != nil {
		return source{}, err
	}
	s := source{text: value, file: filename, original: file}
	rest := raw[1 : len(raw)-1]
	for i := 0; len(rest) > 0; {
		size := 1
		decoded := 1
		if raw[0] == '`' {
			if rest[0] == '\r' {
				i++
				rest = rest[1:]
				continue
			}
		} else {
			r, multibyte, tail, err := strconv.UnquoteChar(rest, '"')
			if err != nil {
				return source{}, err
			}
			size = len(rest) - len(tail)
			if multibyte {
				decoded = utf8.RuneLen(r)
			}
		}
		for j := 0; j < decoded; j++ {
			s.offsets = append(s.offsets, start+1+i+min(j, size-1))
		}
		i += size
		rest = rest[size:]
	}
	s.offsets = append(s.offsets, start+len(raw)-1)
	return s, nil
}

func (s source) position(offset int) [2]int {
	prefix := s.original[:offset]
	return [2]int{strings.Count(prefix, "\n") + 1, offset - strings.LastIndexByte(prefix, '\n')}
}

func (s source) entries() [][3]int {
	var entries [][3]int
	for i := 0; i < len(s.text); i++ {
		original := i
		if s.offsets != nil {
			original = s.offsets[i]
		}
		lineStart := i == 0 || s.text[i-1] == '\n'
		jumped := s.offsets != nil && i > 0 && s.offsets[i] != s.offsets[i-1]+1
		if lineStart || jumped {
			pos := s.position(original)
			entries = append(entries, [3]int{i, pos[0], pos[1]})
		}
	}
	if entries == nil {
		pos := s.position(0)
		if s.offsets != nil {
			pos = s.position(s.offsets[0])
		}
		entries = [][3]int{{0, pos[0], pos[1]}}
	}
	return entries
}
