package main

import (
	"fmt"
	"log"

	"example.com/embed-models/orders"
	"example.com/embed-models/receipts"
)

func main() {
	order, err := orders.MakeOrder(orders.Item{Name: "tea", Quantity: 3})
	if err != nil {
		log.Fatal(err)
	}
	count, err := receipts.Count(order)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(count)
}
