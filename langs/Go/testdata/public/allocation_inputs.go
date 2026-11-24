package allocations

import (
	"encoding/json"
	"math/big"
)

var initialOrder = Order{Qty: big.NewInt(12), Price: big.NewInt(25)}

var initialJSON, initialJSONErr = json.Marshal(initialOrder)

var initialTwice, initialTwiceErr = Twice(big.NewInt(7))

var initialTotal, initialTotalErr = Total(initialOrder)
