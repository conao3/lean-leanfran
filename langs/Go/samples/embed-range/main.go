package main

import (
	"fmt"
	"log"
	"math/big"

	"example.com/embed-range/pricing"
)

func main() {
	r, err := pricing.NewRange(big.NewInt(2), big.NewInt(5))
	if err != nil {
		log.Fatal(err)
	}
	width, err := pricing.Width(r)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(width)
}
