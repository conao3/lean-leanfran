package main

import (
	"bufio"
	"fmt"
	"log"
	"math/big"
	"math/rand/v2"
	"os"
	"strconv"
	"strings"
)

var boundaries = []string{
	"NAT\t0\t0",
	"NAT\t1\t2",
	"NAT\t9223372036854775807\t1",
	"NAT\t9223372036854775808\t9223372036854775809",
	"NAT\t18446744073709551616\t18446744073709551615",
	"NAT\t123456789012345678901234567890\t18446744073709551616",
	"INT\t0\t0",
	"INT\t-7\t2",
	"INT\t7\t-2",
	"INT\t-7\t-2",
	"INT\t-9223372036854775808\t-1",
	"INT\t-9223372036854775809\t9223372036854775808",
	"U64\t0\t0",
	"U64\t18446744073709551615\t1",
	"U64\t18446744073709551615\t9223372036854775808",
	"U64\t9223372036854775808\t63",
	"U64\t9223372036854775808\t64",
	"U64\t4611686293305294849\t9223372036854775807",
	"STR\t\t",
	"STR\té\t猫",
	"STR\ta \t",
	"STR\t🍣\té",
	"STR\t\\$\t𐀀",
	"ARR",
	"ARR\t0",
	"ARR\t1\t9223372036854775808\t18446744073709551616",
}

func natural(random *rand.Rand, size int) string {
	data := make([]byte, size)
	for i := range data {
		data[i] = byte(random.Uint32())
	}
	return new(big.Int).SetBytes(data).String()
}

func integer(random *rand.Rand) string {
	n := natural(random, 1+random.IntN(16))
	if random.IntN(2) == 0 {
		return "-" + n
	}
	return n
}

func unicodeString(random *rand.Rand) string {
	alphabet := []rune("aZ$\\ é́猫🌱𐀀𐌀")
	var text strings.Builder
	for range random.IntN(17) {
		text.WriteRune(alphabet[random.IntN(len(alphabet))])
	}
	return text.String()
}

func randomRow(random *rand.Rand) []string {
	switch random.IntN(5) {
	case 0:
		return []string{"NAT", natural(random, 1+random.IntN(16)), natural(random, 1+random.IntN(16))}
	case 1:
		return []string{"INT", integer(random), integer(random)}
	case 2:
		a := random.Uint64()
		b := random.Uint64()
		if random.IntN(2) == 0 {
			b = uint64(random.IntN(129))
		}
		return []string{"U64", strconv.FormatUint(a, 10), strconv.FormatUint(b, 10)}
	case 3:
		return []string{"STR", unicodeString(random), unicodeString(random)}
	default:
		fields := []string{"ARR"}
		for range random.IntN(17) {
			fields = append(fields, natural(random, 1+random.IntN(12)))
		}
		return fields
	}
}

func main() {
	if len(os.Args) != 3 {
		log.Fatal("usage: fuzz-gen SEED COUNT")
	}
	seed, seedErr := strconv.ParseUint(os.Args[1], 10, 64)
	count, countErr := strconv.Atoi(os.Args[2])
	if seedErr != nil || countErr != nil || count < 0 {
		log.Fatal("expected an unsigned seed and a nonnegative count")
	}
	random := rand.New(rand.NewPCG(seed, 0))
	out := bufio.NewWriter(os.Stdout)
	write := func(row string) {
		if _, err := fmt.Fprintln(out, row); err != nil {
			log.Fatal(err)
		}
	}
	for _, line := range boundaries {
		write(line)
	}
	for range count {
		write(strings.Join(randomRow(random), "\t"))
	}
	if err := out.Flush(); err != nil {
		log.Fatal(err)
	}
}
