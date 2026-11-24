package main

import (
	"encoding/json"
	"fmt"
	"math/big"

	"github.com/conao3/leanfran-go/samples/pricing/pricing"
)

func main() {
	discount, err := pricing.NewDiscountPercent(big.NewInt(10))
	if err != nil {
		panic(err)
	}
	total, err := pricing.Total([]*big.Int{big.NewInt(1200), big.NewInt(800)}, discount)
	if err != nil {
		panic(err)
	}
	fmt.Println(total)

	var r pricing.Range
	if err := json.Unmarshal([]byte(`{"lo":1,"hi":3}`), &r); err != nil {
		panic(err)
	}
	data, err := json.Marshal(r)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(data))
}
