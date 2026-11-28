package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strconv"

	"github.com/conao3/leanfran-go"
	"github.com/conao3/leanfran-go/internal/embed"
)

const install = "install the compiler of this release with nix profile install 'github:conao3/lean-leanfran/v" + leanfran.Version + "#leanfran'"

func main() {
	os.Exit(run(os.Args[1:]))
}

func versions() (embed.Versions, bool) {
	v := embed.Versions{
		Release: os.Getenv("LEANFRAN_VERSION"), Generator: os.Getenv("LEANFRAN_GENERATOR_VERSION"),
		Lean: os.Getenv("LEANFRAN_LEAN_VERSION"),
	}
	for _, check := range []struct {
		name, got, want, fix string
	}{
		{"release version", v.Release, leanfran.Version, "use a compiler from the Go module's release or update the Go module to the compiler's release"},
		{"generator version", v.Generator, strconv.Itoa(leanfran.GeneratorVersion), "rebuild the compiler from the Go module's source revision"},
		{"Lean version", v.Lean, embed.LeanVersion, "use a compiler built with the Lean version of the Go module's release"},
	} {
		if check.got == "" {
			fmt.Fprintln(os.Stderr, "leanfran-go: run leanfran --lang go sync, check or status in the Go project")
			return v, false
		}
		if check.got != check.want {
			fmt.Fprintf(os.Stderr, "leanfran-go: compiler %s %q, expected %s; %s, or %s\n", check.name, check.got, check.want, check.fix, install)
			return v, false
		}
	}
	return v, true
}

func run(args []string) int {
	if len(args) == 0 || args[0] != "scan" && args[0] != "translate" {
		fmt.Fprintln(os.Stderr, "usage: leanfran-go scan --root <root> --dir <dir>\n       leanfran-go translate --root <root>")
		return 252
	}
	command := args[0]
	flags := flag.NewFlagSet("leanfran-go "+command, flag.ContinueOnError)
	root := flags.String("root", "", "root of the Go module")
	if command == "scan" {
		flags.String("dir", "", "directory within the Go module")
	}
	if err := flags.Parse(args[1:]); err != nil || flags.NArg() != 0 || *root == "" {
		fmt.Fprintf(os.Stderr, "leanfran-go %s: expected --root <root>\n", command)
		return 252
	}
	v, ok := versions()
	if !ok {
		return 255
	}
	var result any
	var err error
	if command == "scan" {
		result, err = embed.Scan(*root, v)
	} else {
		var input embed.TranslateInput
		if err := json.NewDecoder(os.Stdin).Decode(&input); err != nil {
			fmt.Fprintf(os.Stderr, "leanfran-go translate: invalid input: %v\n", err)
			return 255
		}
		result, err = embed.Translate(*root, v, input)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 254
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		fmt.Fprintf(os.Stderr, "leanfran-go %s: %v\n", command, err)
		return 255
	}
	return 0
}
