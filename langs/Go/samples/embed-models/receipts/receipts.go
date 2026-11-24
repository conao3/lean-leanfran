package receipts

import lf "github.com/conao3/leanfran-go"

var _ = lf.LeanFile("receipt.lean", lf.Uses("example.com/embed-models/orders"))
