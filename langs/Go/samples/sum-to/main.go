package main

import (
	"fmt"

	"github.com/conao3/leanfran-go/rt"
	"github.com/conao3/leanfran-go/samples/sum-to/arith"
)

func main() {
	fmt.Println(rt.NatString(arith.L_sumTo(rt.NatFromUint64(1_000_000), rt.NatFromUint64(0))))
}
