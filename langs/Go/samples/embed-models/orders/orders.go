package orders

import "github.com/conao3/leanfran-go"

type Item struct {
	Name     string `leanfran:"min_len=1"`
	Quantity uint16 `leanfran:"ge=1,le=100"`
}

var _ = leanfran.Lean(`
structure Order where
  item : Item

def makeOrder (item : Item) : Order := ⟨item⟩
`, leanfran.Models(Item{}))
