package main

import (
	"bufio"
	"fmt"
	"io"
	"math"
	"math/big"
	"math/rand/v2"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
)

const (
	randomCases = 2000
	seed        = 20261121
)

type operation struct {
	key      string
	symbol   string
	function string
	inputs   []string
	output   string
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func mustWrite(_ int, err error) { must(err) }

func open(dir, name string) *os.File {
	file, err := os.Open(filepath.Join(dir, name))
	must(err)
	return file
}

func create(dir, name string) *os.File {
	file, err := os.Create(filepath.Join(dir, name))
	must(err)
	return file
}

func operations(dir string) []operation {
	file := open(dir, "externs.tsv")
	defer func() { must(file.Close()) }()
	scanner := bufio.NewScanner(file)
	seen := make(map[string]bool)
	symbols := make(map[string]bool)
	var result []operation
	declarations := 0
	for scanner.Scan() {
		fields := strings.Split(scanner.Text(), "\t")
		if len(fields) != 3 {
			panic("malformed numeric extern inventory: " + scanner.Text())
		}
		name, symbol, signature := fields[0], fields[1], fields[2]
		owner, method, _ := strings.Cut(name, ".")
		declarations++
		symbols[symbol] = true
		key := symbol
		switch method {
		case "gcd._unary", "powMod._unary", "ofModel", "toModel", "toBitVec":
			continue
		case "ofNatLT", "ofNat32":
			key += "@" + name
		}
		if owner == "Char" {
			key += "@" + name
		}
		if seen[key] {
			continue
		}
		seen[key] = true
		op := operation{key: key, symbol: symbol, function: name, output: owner}
		switch {
		case method == "ofNatLT":
			op.inputs = []string{"Bounded" + owner}
		case method == "ofNat32":
			op.inputs = []string{"BoundedUInt32"}
		case owner == "Char":
			op.function, op.inputs, op.output = "charOfNat", []string{"ValidChar"}, "Nat"
		case method == "divExact":
			op.function, op.inputs = strings.ToLower(owner)+"DivExact", []string{owner, owner}
		case method == "decNonneg":
			op.inputs, op.output = []string{owner}, "Decidable"
		case strings.HasPrefix(method, "dec"):
			op.inputs, op.output = []string{owner, owner}, "Decidable"
		case method == "ofBitVec":
			op.inputs = []string{"Bits" + owner}
		case method == "frExp":
			op.inputs, op.output = []string{owner}, owner+"Pair"
		default:
			signature = strings.NewReplacer("([mdata borrowed:1 Nat])", "Nat", "([mdata borrowed:1 Int])", "Int").Replace(signature)
			types := strings.Split(signature, " -> ")
			op.inputs, op.output = types[:len(types)-1], types[len(types)-1]
		}
		result = append(result, op)
	}
	must(scanner.Err())
	if declarations == 0 {
		panic("empty Init numeric extern inventory")
	}
	for symbol := range symbols {
		if !seen[symbol] {
			panic("missing numeric oracle case: " + symbol)
		}
	}
	fmt.Printf("numeric extern inventory: %d declarations, %d C symbols, 0 missing\n", declarations, len(symbols))
	result = append(result,
		operation{"lean_cstr_to_nat", "lean_cstr_to_nat", "String.toNat!", []string{"DecimalNat"}, "Nat"},
		operation{"lean_cstr_to_int", "lean_cstr_to_int", "String.toInt!", []string{"DecimalInt"}, "Int"},
		operation{"lean_nat_repr", "lean_nat_repr", "toString", []string{"Nat"}, "String"},
		operation{"lean_int_repr", "lean_int_repr", "toString", []string{"Int"}, "String"},
		operation{"lean_nat_succ", "lean_nat_succ", "Nat.succ", []string{"Nat"}, "Nat"},
		operation{"lean_int_to_nat", "lean_int_to_nat", "Int.toNat", []string{"Int"}, "Nat"},
		operation{"lean_int_pow", "lean_int_pow", "HPow.hPow", []string{"Int", "Nat"}, "Int"},
		operation{"lean_int_shift_right", "lean_int_shift_right", "Int.shiftRight", []string{"Int", "Nat"}, "Int"},
		operation{"lean_float_of_nat", "lean_float_of_nat", "Float.ofNat", []string{"Nat"}, "Float"},
		operation{"lean_float32_of_nat", "lean_float32_of_nat", "Float32.ofNat", []string{"Nat"}, "Float32"},
		operation{"lean_float_of_int", "lean_float_of_int", "Float.ofInt", []string{"Int"}, "Float"},
		operation{"lean_float32_of_int", "lean_float32_of_int", "Float32.ofInt", []string{"Int"}, "Float32"},
		operation{"lean_float_of_scientific", "lean_float_of_scientific", "Float.ofScientific", []string{"Nat", "Bool", "Nat"}, "Float"},
		operation{"lean_float32_of_scientific", "lean_float32_of_scientific", "Float32.ofScientific", []string{"Nat", "Bool", "Nat"}, "Float32"},
		operation{"fmod", "fmod", "fmod64", []string{"Float", "Float"}, "Float"},
		operation{"fmodf", "fmodf", "fmod32", []string{"Float32", "Float32"}, "Float32"},
	)
	for _, src := range []string{"Int8", "Int16", "Int32", "Int64", "ISize"} {
		for _, dst := range []string{"UInt8", "UInt16", "UInt32", "UInt64", "USize"} {
			symbol := "lean_" + strings.ToLower(src) + "_to_" + strings.ToLower(dst)
			call := fmt.Sprintf("(fun (x : %s) => %s.ofNat (x.toInt %% (2 ^ %d)).toNat)", src, dst, width(dst))
			result = append(result, operation{symbol, symbol, call, []string{src}, dst})
		}
	}
	return result
}

func width(name string) int {
	switch strings.TrimPrefix(strings.TrimPrefix(name, "Bounded"), "Bits") {
	case "Int8", "UInt8":
		return 8
	case "Int16", "UInt16":
		return 16
	case "Int32", "UInt32":
		return 32
	case "Int64", "UInt64", "ISize", "USize":
		return 64
	default:
		return 0
	}
}

func leanInput(typ, arg string) string {
	nat := "(" + arg + ".toNat!)"
	switch typ {
	case "DecimalNat", "DecimalInt":
		return arg
	case "Nat", "ValidChar":
		return nat
	case "Int":
		return "(" + arg + ".toInt!)"
	case "Bool":
		return "(bool " + arg + ")"
	case "Float":
		return "(float " + arg + ")"
	case "Float32":
		return "(float32 " + arg + ")"
	case "BitsUSize":
		return "(BitVec.ofNat System.Platform.numBits " + nat + ")"
	}
	switch {
	case strings.HasPrefix(typ, "Bounded"):
		return nat
	case strings.HasPrefix(typ, "Bits"):
		return fmt.Sprintf("(BitVec.ofNat %d %s)", width(typ), nat)
	case strings.HasPrefix(typ, "U"):
		return "(" + typ + ".ofNat " + nat + ")"
	case width(typ) != 0:
		return "(" + typ + ".ofInt (" + arg + ".toInt!))"
	default:
		panic("unknown Lean input type: " + typ)
	}
}

func leanOutput(typ, call string) string {
	switch typ {
	case "Decidable":
		return "showBool (decision (" + call + "))"
	case "Bool", "Float", "Float32", "FloatPair", "Float32Pair":
		return "show" + typ + " (" + call + ")"
	case "String":
		return call
	case "Nat", "Int":
		return "toString (" + call + ")"
	}
	if strings.HasPrefix(typ, "U") {
		return "toString ((" + call + ").toNat)"
	}
	return "toString ((" + call + ").toInt)"
}

func goInput(typ, arg string) string {
	switch typ {
	case "DecimalNat", "DecimalInt":
		return arg
	case "Float":
		return "rt.Lean_float_of_bits(unsigned(" + arg + "))"
	case "Float32":
		return "rt.Lean_float32_of_bits(uint32(unsigned(" + arg + ")))"
	case "Bool":
		return "uint8(unsigned(" + arg + "))"
	case "Nat", "ValidChar":
		return "rt.Lean_cstr_to_nat(" + arg + ")"
	case "Int":
		return "rt.Lean_cstr_to_int(" + arg + ")"
	}
	switch {
	case strings.HasPrefix(typ, "Bits"), strings.HasPrefix(typ, "Bounded"):
		return "rt.Lean_cstr_to_nat(" + arg + ")"
	case strings.HasPrefix(typ, "U"):
		return fmt.Sprintf("uint%d(unsigned(%s))", width(typ), arg)
	default:
		return fmt.Sprintf("uint%d(signed(%s))", width(typ), arg)
	}
}

func goOutput(typ, call string) string {
	switch typ {
	case "Bool", "Decidable":
		return "boolString(" + call + ")"
	case "Float":
		return "strconv.FormatUint(rt.Lean_float_to_bits(" + call + "), 10)"
	case "Float32":
		return "strconv.FormatUint(uint64(rt.Lean_float32_to_bits(" + call + ")), 10)"
	case "FloatPair", "Float32Pair":
		return "pairString(" + call + ", " + strconv.FormatBool(typ == "Float32Pair") + ")"
	case "String":
		return "rt.String(" + call + ")"
	case "Nat":
		return "natString(" + call + ")"
	case "Int":
		return "intString(" + call + ")"
	}
	if strings.HasPrefix(typ, "U") {
		return "strconv.FormatUint(uint64(" + call + "), 10)"
	}
	return fmt.Sprintf("strconv.FormatInt(int64(int%d(%s)), 10)", width(typ), call)
}

const goHeader = `package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/conao3/leanfran-go/rt"
)

func unsigned(arg string) uint64 {
	n, err := strconv.ParseUint(arg, 10, 64)
	if err != nil { panic(err) }
	return n
}

func signed(arg string) int64 {
	n, err := strconv.ParseInt(arg, 10, 64)
	if err != nil { panic(err) }
	return n
}

func boolString(value uint8) string {
	if value > 1 { panic(fmt.Sprintf("invalid Bool: %d", value)) }
	return strconv.Itoa(int(value))
}

func natString(value rt.V) string {
	s := rt.NatString(value)
	_, err := strconv.ParseInt(s, 10, 64)
	if rt.Lean_is_scalar(value) != (err == nil) {
		panic("noncanonical Nat: " + s)
	}
	return s
}

func intString(value rt.V) string {
	s := rt.IntString(value)
	_, err := strconv.ParseInt(s, 10, 64)
	if rt.Lean_is_scalar(value) != (err == nil) {
		panic("noncanonical Int: " + s)
	}
	return s
}

func pairString(value rt.V, single bool) string {
	fraction, exponent := rt.Lean_ctor_get(value, 0), rt.Lean_ctor_get(value, 1)
	if single {
		return fmt.Sprintf("%d,%s", rt.Lean_float32_to_bits(rt.Lean_unbox_float32(fraction)), rt.IntString(exponent))
	}
	return fmt.Sprintf("%d,%s", rt.Lean_float_to_bits(rt.Lean_unbox_float(fraction)), rt.IntString(exponent))
}

func main() {
	defer rt.RecoverInternalPanic()
	scanner := bufio.NewScanner(os.Stdin)
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	for scanner.Scan() {
		fields := strings.Split(scanner.Text(), "\t")
		fmt.Fprintln(out, dispatch(fields))
	}
	if err := scanner.Err(); err != nil { panic(err) }
}

func dispatch(fields []string) string {
	switch fields[0] {
`

func dispatch(dir string, ops []operation) {
	lean := create(dir, "NumericDispatch.lean")
	defer func() { must(lean.Close()) }()
	native := create(dir, "dispatch.go")
	defer func() { must(native.Close()) }()
	mustWrite(fmt.Fprintln(lean, "import LeanGoTest.NumericOracleMain\n\nset_option maxHeartbeats 0\nset_option maxRecDepth 4096\n\nnamespace NumericOracle"))
	mustWrite(native.WriteString(goHeader))
	var handlers []string
	for index, op := range ops {
		binders := []string{"a", "b", "c"}[:len(op.inputs)]
		var leanArgs, goArgs []string
		for i, typ := range op.inputs {
			leanArgs = append(leanArgs, leanInput(typ, binders[i]))
			goArgs = append(goArgs, goInput(typ, fmt.Sprintf("fields[%d]", i+2)))
		}
		call := op.function + " " + strings.Join(leanArgs, " ")
		if strings.HasPrefix(op.inputs[0], "Bounded") {
			bound := op.output + ".size"
			if op.function == "USize.ofNat32" {
				bound = "(2 ^ 32)"
			}
			call = fmt.Sprintf("if h : %s < %s then %s h else panic! %q", leanArgs[0], bound, call, "invalid "+op.function+" input")
		}
		mustWrite(fmt.Fprintf(lean, "\ndef run_%d (%s : String) : String :=\n  %s\n", index, strings.Join(binders, " "), leanOutput(op.output, call)))
		handlers = append(handlers, fmt.Sprintf("  (fun (args : List String) => match args with | [%s] => some (run_%d %s) | _ => none)", strings.Join(binders, ", "), index, strings.Join(binders, " ")))
		goCall := "rt." + strings.ToUpper(op.symbol[:1]) + op.symbol[1:] + "(" + strings.Join(goArgs, ", ") + ")"
		goResult := goOutput(op.output, goCall)
		if op.function == "charOfNat" {
			goResult = goOutput("UInt32", goCall)
		}
		mustWrite(fmt.Fprintf(native, "\tcase %q:\n\t\treturn %s\n", strconv.Itoa(index), goResult))
	}
	mustWrite(fmt.Fprintln(lean, "\ndef handlers : Array (List String → Option String) := #["))
	mustWrite(fmt.Fprintln(lean, strings.Join(handlers, ",\n")))
	mustWrite(fmt.Fprintln(lean, "]\n\ndef dispatch (i : Nat) (args : List String) : Option String :=\n  handlers[i]?.bind (· args)"))
	mustWrite(fmt.Fprintln(lean, "\nend NumericOracle\n\ndef main : IO Unit := NumericOracle.run NumericOracle.dispatch"))
	mustWrite(fmt.Fprint(native, "\tdefault:\n\t\tpanic(\"unknown numeric test case: \" + fields[0])\n\t}\n}\n"))
}

func integerBounds(typ string) []string {
	w := width(typ)
	signed := typ == "DecimalInt" || strings.HasPrefix(typ, "I")
	result := []string{"0", "1", "2", "3"}
	if signed {
		result = append(result, "-1", "-2", "-3")
	}
	if w == 0 || w == 64 && !signed {
		result = append(result, "4611686293305294848", "4611686293305294849")
	}
	bits := w
	if signed && w != 0 {
		bits--
	}
	limit := new(big.Int).Lsh(big.NewInt(1), uint(bits))
	for _, shift := range []uint{7, 8, 15, 16, 23, 24, 31, 32, 53, 63, 64} {
		power := new(big.Int).Lsh(big.NewInt(1), shift)
		for _, delta := range []int64{-1, 0, 1} {
			positive := new(big.Int).Add(power, big.NewInt(delta))
			if w == 0 || positive.Cmp(limit) < 0 {
				result = append(result, positive.String())
			}
			if signed && (w == 0 || positive.Cmp(limit) <= 0) {
				result = append(result, positive.Neg(positive).String())
			}
		}
	}
	return result
}

func floatBits(value float64, single bool) uint64 {
	if single {
		return uint64(math.Float32bits(float32(value)))
	}
	return math.Float64bits(value)
}

func floatBounds(single bool) []string {
	values := []float64{
		0, 0.5, 1, 1.5, 2, 3, 6, 10, 24, 127, 128, 149, 150, 255, 256, 65536, 2147483648,
		9223372036854775808, 18446744073709551616, 0.0078125, math.Inf(1), math.NaN(),
	}
	var result []string
	for _, value := range values {
		result = append(result, strconv.FormatUint(floatBits(value, single), 10))
		result = append(result, strconv.FormatUint(floatBits(math.Copysign(value, -1), single), 10))
	}
	extra := []uint64{
		0x0000000000000001, 0x8000000000000001, 0x000fffffffffffff, 0x800fffffffffffff,
		0x0010000000000000, 0x8010000000000000, 0x7fefffffffffffff, 0xffefffffffffffff,
		0x7ff0000000000001, 0xfff0000000000001, 0x3fdfffffffffffff, 0x3fe0000000000001,
		0x3fefffffffffffff, 0x3ff0000000000001, 0x9508b92445a1549c, 0x4081e91440000000, 0x3ffffeb9c0000000,
	}
	if single {
		extra = []uint64{
			0x00000001, 0x80000001, 0x007fffff, 0x807fffff, 0x00800000, 0x80800000,
			0x7f7fffff, 0xff7fffff, 0x7f800001, 0xff800001, 0x3effffff, 0x3f000001, 0x3f7fffff, 0x3f800001, 0xd4350b28,
		}
	}
	for _, bits := range extra {
		result = append(result, strconv.FormatUint(bits, 10))
	}
	return result
}

func bounds(op operation, i int) []string {
	typ := op.inputs[i]
	switch typ {
	case "Float", "Float32":
		return floatBounds(typ == "Float32")
	case "Bool":
		return []string{"0", "1"}
	case "ValidChar":
		return []string{"0", "1", "127", "128", "55295", "57344", "65535", "65536", "1114111"}
	}
	result := integerBounds(typ)
	if i == 1 && bigResult(op.symbol) {
		result = append(result, "63", "64", "65", "127", "128", "149", "255", "256", "1024", "4294967296")
	}
	if i == 2 && strings.HasSuffix(op.symbol, "_of_scientific") {
		result = append(result, "22", "23", "38", "45", "46", "308", "309", "324", "325")
	}
	seen := make(map[string]bool)
	return slices.DeleteFunc(result, func(s string) bool {
		duplicate := seen[s]
		seen[s] = true
		return duplicate
	})
}

func randomOperand(rng *rand.Rand, typ string, index int) string {
	switch typ {
	case "Bool":
		return strconv.Itoa(rng.IntN(2))
	case "ValidChar":
		value := rng.IntN(0x110000 - 0x800)
		if value >= 0xd800 {
			value += 0x800
		}
		return strconv.Itoa(value)
	case "Float", "Float32":
		single := typ == "Float32"
		if index%3 == 2 {
			if single {
				return strconv.FormatUint(uint64(rng.Uint32()), 10)
			}
			return strconv.FormatUint(rng.Uint64(), 10)
		}
		divisor := float64(8192)
		if index%3 == 1 {
			divisor = 4194304
		}
		value := float64(rng.IntN(1<<24)-1<<23) / divisor
		return strconv.FormatUint(floatBits(value, single), 10)
	}
	w := width(typ)
	if w == 0 {
		w = []int{8, 32, 64, 128, 256}[index%5]
	}
	limit := new(big.Int).Lsh(big.NewInt(1), uint(w))
	var value big.Int
	for range w / 8 {
		value.Lsh(&value, 8)
		value.Or(&value, new(big.Int).SetUint64(uint64(rng.IntN(256))))
	}
	if (typ == "DecimalInt" || strings.HasPrefix(typ, "I")) && value.Bit(w-1) != 0 {
		value.Sub(&value, limit)
	}
	return value.String()
}

func integer(s string) *big.Int {
	result, ok := new(big.Int).SetString(s, 10)
	if !ok {
		panic("invalid numeric input: " + s)
	}
	return result
}

func bigResult(symbol string) bool {
	switch symbol {
	case "lean_nat_pow", "lean_nat_powmod", "lean_int_pow", "lean_nat_shiftl":
		return true
	default:
		return false
	}
}

func unsafeResultSize(symbol string, args []string) bool {
	return bigResult(symbol) &&
		(symbol != "lean_nat_powmod" || args[2] == "0") &&
		args[0] != "0" &&
		(symbol == "lean_nat_shiftl" || args[0] != "1" && args[0] != "-1") &&
		integer(args[1]).Cmp(big.NewInt(1024)) > 0
}

func rows(dir string, ops []operation) {
	input := create(dir, "input")
	defer func() { must(input.Close()) }()
	checkedPanics := create(dir, "panic-input")
	defer func() { must(checkedPanics.Close()) }()
	out := bufio.NewWriter(input)
	rng := rand.New(rand.NewPCG(seed, 0))
	for index, op := range ops {
		write := func(fd io.Writer, args []string) {
			mustWrite(fmt.Fprintf(fd, "%d\t%s\t%s\n", index, op.key, strings.Join(args, "\t")))
		}
		exactDiv := op.symbol == "lean_int_div_exact" || op.symbol == "lean_nat_div_exact"
		args := make([]string, len(op.inputs))
		var operands [][]string
		for i := range args {
			operands = append(operands, bounds(op, i))
		}
		var product func(int)
		product = func(i int) {
			if i < len(args) {
				for _, value := range operands[i] {
					args[i] = value
					product(i + 1)
				}
				return
			}
			if exactDiv && (args[1] == "0" || new(big.Int).Rem(integer(args[0]), integer(args[1])).Sign() != 0) {
				return
			}
			if unsafeResultSize(op.symbol, args) {
				if op.symbol != "lean_int_pow" && integer(args[1]).Cmp(big.NewInt(math.MaxUint32)) > 0 {
					write(checkedPanics, args)
				}
				return
			}
			write(out, args)
		}
		product(0)
		for i := range randomCases {
			for j, typ := range op.inputs {
				args[j] = randomOperand(rng, typ, i)
			}
			if exactDiv {
				if args[1] == "0" {
					args[1] = "1"
				}
				args[0] = new(big.Int).Mul(integer(args[0]), integer(args[1])).String()
			}
			if unsafeResultSize(op.symbol, args) {
				args[1] = new(big.Int).Mod(integer(args[1]), big.NewInt(257)).String()
			}
			write(out, args)
		}
	}
	must(out.Flush())
}

func transcendental(symbol string) bool {
	switch strings.TrimSuffix(symbol, "f") {
	case "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sinh", "cosh", "tanh",
		"asinh", "acosh", "atanh", "exp", "exp2", "log", "log2", "log10", "pow", "cbrt":
		return true
	default:
		return false
	}
}

func ulpLimit(symbol string) uint64 {
	switch symbol {
	case "acos":
		return 8
	case "cbrt", "log", "log10", "log2", "pow":
		return 4
	case "cos":
		return 128
	case "sin", "tan":
		return 32
	case "sinh":
		return 2
	default:
		return 1
	}
}

func bitsOf(row string) uint64 {
	n, err := strconv.ParseUint(row, 10, 64)
	must(err)
	return n
}

func compareFloats(oracle, runtime string, single bool) (distance uint64, compatible bool) {
	a, b := bitsOf(oracle), bitsOf(runtime)
	sign := uint64(1 << 63)
	infinity := uint64(0x7ff0000000000000)
	if single {
		sign = 1 << 31
		infinity = 0x7f800000
	}
	x, y := a&^sign, b&^sign
	if x > infinity && y > infinity {
		return 0, true
	}
	if x >= infinity || y >= infinity || a&sign != b&sign {
		return 0, a == b
	}
	return max(x, y) - min(x, y), true
}

func compare(dir string, ops []operation) {
	inputFile := open(dir, "input")
	defer func() { must(inputFile.Close()) }()
	oracleFile := open(dir, "oracle.out")
	defer func() { must(oracleFile.Close()) }()
	runtimeFile := open(dir, "runtime.out")
	defer func() { must(runtimeFile.Close()) }()
	input, oracle, runtime := bufio.NewScanner(inputFile), bufio.NewScanner(oracleFile), bufio.NewScanner(runtimeFile)
	byKey := make(map[string]operation)
	for _, op := range ops {
		byKey[op.key] = op
	}
	type measurement struct {
		rows   int
		maxULP uint64
		worst  string
	}
	measurements := make(map[string]measurement)
	exact, approximate, mismatches := 0, 0, 0
	reported := make(map[string]bool)
	for input.Scan() {
		if !oracle.Scan() || !runtime.Scan() {
			panic("numeric output ended at " + input.Text())
		}
		key := strings.SplitN(input.Text(), "\t", 3)[1]
		op := byKey[key]
		expected, actual := oracle.Text(), runtime.Text()
		if transcendental(op.symbol) {
			stats := measurements[key]
			stats.rows++
			distance, compatible := compareFloats(expected, actual, op.output == "Float32")
			if compatible {
				if distance > stats.maxULP {
					stats.maxULP = distance
					stats.worst = input.Text()
				}
			}
			measurements[key] = stats
			if compatible && expected != actual && distance <= ulpLimit(key) {
				approximate++
				continue
			}
		}
		if expected == actual {
			exact++
			continue
		}
		mismatches++
		if !reported[key] {
			fmt.Fprintf(os.Stderr, "%s: Lean %s, Go %s\n", input.Text(), expected, actual)
			reported[key] = true
		}
	}
	if oracle.Scan() || runtime.Scan() {
		panic("unexpected trailing numeric output")
	}
	must(input.Err())
	must(oracle.Err())
	must(runtime.Err())
	for _, op := range ops {
		if stats, ok := measurements[op.key]; ok {
			fmt.Printf("numeric ULP %s: %d (%d inputs) %s\n", op.key, stats.maxULP, stats.rows, stats.worst)
		}
	}
	fmt.Printf("numeric output: %d byte-identical, %d approximate, %d mismatches (%d call cases, %d random inputs each)\n", exact, approximate, mismatches, len(ops), randomCases)
	if mismatches != 0 {
		os.Exit(1)
	}
}

func main() {
	if len(os.Args) != 3 {
		panic("usage: numeric prepare|compare directory")
	}
	dir := os.Args[2]
	ops := operations(dir)
	switch os.Args[1] {
	case "prepare":
		dispatch(dir, ops)
		rows(dir, ops)
	case "compare":
		compare(dir, ops)
	default:
		panic("unknown numeric test phase: " + os.Args[1])
	}
}
