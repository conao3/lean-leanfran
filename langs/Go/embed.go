package leanfran

type Block struct{}

type BlockOption struct{}

func Lean(string, ...BlockOption) Block     { return Block{} }
func LeanFile(string, ...BlockOption) Block { return Block{} }
func Imports(...string) BlockOption         { return BlockOption{} }
func Uses(...string) BlockOption            { return BlockOption{} }
func Models(...any) BlockOption             { return BlockOption{} }
