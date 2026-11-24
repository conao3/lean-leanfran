package consumer

import (
	"example.com/embed-fixture/types"
	"github.com/conao3/leanfran-go"
)

var _ = leanfran.Lean("def unpack (e : Envelope) := e.value\n\ndef alternate := domainEnabled", leanfran.Imports("Domain"), leanfran.Uses("example.com/embed-fixture/types"))

func RoundTrip(r types.Record) (types.Record, error) {
	e, err := types.Pack(r)
	if err != nil {
		return types.Record{}, err
	}
	return Unpack(e)
}
