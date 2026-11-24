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

func (s source) location(row, column int) (int, int) {
	offset := 0
	for i := 1; i < row; i++ {
		n := strings.IndexByte(s.text[offset:], '\n')
		if n < 0 {
			offset = len(s.text)
			break
		}
		offset += n + 1
	}
	for i := 0; i < column && offset < len(s.text) && s.text[offset] != '\n'; i++ {
		_, width := utf8.DecodeRuneInString(s.text[offset:])
		offset += width
	}
	if s.offsets != nil {
		offset = s.offsets[offset]
	}
	prefix := s.original[:offset]
	return strings.Count(prefix, "\n") + 1, offset - strings.LastIndexByte(prefix, '\n')
}
