package main

import (
	"fmt"
	"log"
	"math/big"

	"example.com/embed-fixture/consumer"
)

func main() {
	count, err := consumer.CountTwice(big.NewInt(7))
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(count)
}
