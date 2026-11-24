module example.com/verified-nibble

go 1.26

require github.com/conao3/leanfran-go v0.10.0

replace github.com/conao3/leanfran-go => ../..

tool github.com/conao3/leanfran-go/cmd/leanfran
