package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/conao3/leanfran-go/internal/embed"
)

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	if len(args) == 0 || args[0] == "--help" || args[0] == "-h" {
		_, err := fmt.Fprintln(os.Stdout, "usage: leanfran sync|status|check [--dir dir] [--leanfran-go path]")
		if len(args) == 0 || err != nil {
			return 1
		}
		return 0
	}
	command := args[0]
	if command != "sync" && command != "status" && command != "check" {
		fmt.Fprintf(os.Stderr, "leanfran: unknown command %q\n", command)
		return 1
	}
	flags := flag.NewFlagSet("leanfran "+command, flag.ContinueOnError)
	dir := flags.String("dir", ".", "directory within the Go module")
	var compiler, require string
	if command == "check" {
		flags.StringVar(&require, "require", "", "require every obligation to be proved")
	}
	if command != "status" {
		flags.StringVar(&compiler, "leanfran-go", "", "path to the Lean-to-Go compiler")
	}
	if err := flags.Parse(args[1:]); err != nil {
		if err == flag.ErrHelp {
			return 0
		}
		return 1
	}
	if flags.NArg() != 0 {
		fmt.Fprintln(os.Stderr, "leanfran: unexpected positional arguments")
		return 1
	}
	if require != "" && require != "proved" {
		fmt.Fprintf(os.Stderr, "leanfran: invalid proof requirement %q\n", require)
		return 1
	}
	if err := embed.Run(command, *dir, compiler, require == "proved", os.Stdout, os.Stderr); err != nil {
		fmt.Fprintf(os.Stderr, "leanfran: %v\n", err)
		return 1
	}
	return 0
}
