package types

import (
	"math/big"

	"github.com/conao3/leanfran-go"
)

type Color string

const (
	Amber Color = "orange"
	Blue  Color = "ice blue"
)

type Nested struct {
	Enabled bool
}

type Record struct {
	I8   int8
	I16  int16
	I32  int32
	I64  int64
	U8   uint8
	U16  uint16
	U32  uint32
	U64  uint64
	I    int `leanfran:"ge=-7,le=100"`
	U    uint
	Big  *big.Int
	Nat  *big.Int `leanfran:"ge=0"`
	F64  float64
	F32  float32
	B    bool
	S    string `leanfran:"min_len=2"`
	R    rune
	List []int  `leanfran:"min_items=1"`
	Data []byte `leanfran:"min_items=1"`
	Opt  *uint
	Sub  Nested
	Tint Color
}

var _ = leanfran.Lean(`
structure Envelope where
  value : Record

def pack (value : Record) : Envelope := ⟨value⟩

def echoColor (value : Color) : Color := value
`, leanfran.Imports("Std.Data.HashMap"), leanfran.Models(Record{}, Color("")))
