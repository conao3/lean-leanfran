package rt

import (
	"math"
	"math/big"
	"math/bits"
	"strconv"
)

func bigValue(n *big.Int) V {
	return V{p: &Obj{rc: 1, kind: kindBigInt, x: n}}
}

func natValue(n *big.Int) V {
	if n.BitLen() < 64 {
		return V{n: n.Uint64()}
	}
	return bigValue(n)
}

func intValue(n *big.Int) V {
	if n.IsInt64() {
		return IntFromInt64(n.Int64())
	}
	return bigValue(n)
}

func natBig(v V) *big.Int {
	if v.p == nil {
		return new(big.Int).SetUint64(v.n)
	}
	return v.p.x.(*big.Int)
}

func intBig(v V) *big.Int {
	if v.p == nil {
		return big.NewInt(int64(v.n))
	}
	return v.p.x.(*big.Int)
}

func NatFromUint64(n uint64) V {
	if n <= math.MaxInt64 {
		return V{n: n}
	}
	return bigValue(new(big.Int).SetUint64(n))
}

func IntFromInt64(n int64) V { return V{n: uint64(n)} }

func NatString(n V) string {
	if n.p == nil {
		return strconv.FormatUint(n.n, 10)
	}
	return natBig(n).String()
}

func IntString(n V) string {
	if n.p == nil {
		return strconv.FormatInt(int64(n.n), 10)
	}
	return intBig(n).String()
}

func Lean_cstr_to_nat(s string) V {
	if n, err := strconv.ParseUint(s, 10, 64); err == nil {
		return NatFromUint64(n)
	}
	n, ok := new(big.Int).SetString(s, 10)
	if !ok || n.Sign() < 0 {
		Lean_internal_panic("invalid Nat literal: " + s)
	}
	return natValue(n)
}

func Lean_cstr_to_int(s string) V {
	if n, err := strconv.ParseInt(s, 10, 64); err == nil {
		return IntFromInt64(n)
	}
	n, ok := new(big.Int).SetString(s, 10)
	if !ok {
		Lean_internal_panic("invalid Int literal: " + s)
	}
	return intValue(n)
}

func Lean_nat_repr(n V) V { return Lean_mk_string(NatString(n)) }
func Lean_int_repr(n V) V { return Lean_mk_string(IntString(n)) }

func Lean_nat_add(a, b V) V {
	if a.p == nil && b.p == nil && a.n+b.n <= math.MaxInt64 {
		return V{n: a.n + b.n}
	}
	return natAddBig(a, b)
}

func natAddBig(a, b V) V { return natValue(new(big.Int).Add(natBig(a), natBig(b))) }

func Lean_nat_sub(a, b V) V {
	if a.p == nil && b.p == nil {
		return V{n: a.n - min(a.n, b.n)}
	}
	return natSubBig(a, b)
}

func natSubBig(a, b V) V {
	value := new(big.Int).Sub(natBig(a), natBig(b))
	if value.Sign() < 0 {
		return V{}
	}
	return natValue(value)
}

func Lean_nat_mul(a, b V) V {
	if a.p == nil && b.p == nil {
		hi, lo := bits.Mul64(a.n, b.n)
		if hi == 0 && lo <= math.MaxInt64 {
			return V{n: lo}
		}
	}
	return natValue(new(big.Int).Mul(natBig(a), natBig(b)))
}

func Lean_nat_div(a, b V) V {
	if b == (V{}) {
		return V{}
	}
	if a.p == nil && b.p == nil {
		return V{n: a.n / b.n}
	}
	return natValue(new(big.Int).Quo(natBig(a), natBig(b)))
}

func Lean_nat_div_exact(a, b V) V { return Lean_nat_div(a, b) }

func Lean_nat_mod(a, b V) V {
	if b == (V{}) {
		Lean_inc(a)
		return a
	}
	if a.p == nil && b.p == nil {
		return V{n: a.n % b.n}
	}
	return natValue(new(big.Int).Rem(natBig(a), natBig(b)))
}

func Lean_nat_succ(a V) V { return Lean_nat_add(a, V{n: 1}) }
func Lean_nat_pred(a V) V { return Lean_nat_sub(a, V{n: 1}) }

func Lean_nat_dec_eq(a, b V) uint8 {
	if a.p == nil || b.p == nil {
		return decision(a == b)
	}
	return decision(natBig(a).Cmp(natBig(b)) == 0)
}

func Lean_nat_dec_le(a, b V) uint8 {
	if a.p == nil && b.p == nil {
		return decision(a.n <= b.n)
	}
	return decision(natBig(a).Cmp(natBig(b)) <= 0)
}

func Lean_nat_dec_lt(a, b V) uint8 {
	if a.p == nil && b.p == nil {
		return decision(a.n < b.n)
	}
	return decision(natBig(a).Cmp(natBig(b)) < 0)
}

func Lean_nat_land(a, b V) V {
	if a.p == nil && b.p == nil {
		return V{n: a.n & b.n}
	}
	return natValue(new(big.Int).And(natBig(a), natBig(b)))
}

func Lean_nat_lor(a, b V) V {
	if a.p == nil && b.p == nil {
		return V{n: a.n | b.n}
	}
	return natValue(new(big.Int).Or(natBig(a), natBig(b)))
}

func Lean_nat_lxor(a, b V) V {
	if a.p == nil && b.p == nil {
		return V{n: a.n ^ b.n}
	}
	return natValue(new(big.Int).Xor(natBig(a), natBig(b)))
}

func Lean_nat_log2(a V) V {
	if a.p == nil {
		return V{n: uint64(max(0, bits.Len64(a.n)-1))}
	}
	return V{n: uint64(natBig(a).BitLen() - 1)}
}

func Lean_nat_shiftl(a, b V) V {
	if a == (V{}) {
		return a
	}
	if b.p != nil || b.n > math.MaxUint32 {
		Lean_internal_panic("Nat.shiftl exponent is too big")
	}
	if a.p == nil && b.n < 63 && a.n <= math.MaxInt64>>b.n {
		return V{n: a.n << b.n}
	}
	return natValue(new(big.Int).Lsh(natBig(a), uint(b.n)))
}

func Lean_nat_shiftr(a, b V) V {
	if b.p != nil {
		return V{}
	}
	if a.p == nil {
		return V{n: a.n >> b.n}
	}
	return natValue(new(big.Int).Rsh(natBig(a), uint(b.n)))
}

func Lean_int_shift_right(a, b V) V {
	if b.p != nil {
		if Lean_int_dec_nonneg(a) != 0 {
			return V{}
		}
		return IntFromInt64(-1)
	}
	if a.p == nil {
		return IntFromInt64(int64(a.n) >> b.n)
	}
	return intValue(new(big.Int).Rsh(intBig(a), uint(b.n)))
}

func integerPow(a, b *big.Int) *big.Int {
	if a.BitLen() > 1 && (!b.IsUint64() || b.Uint64() > math.MaxUint32) {
		Lean_internal_panic("Nat.pow exponent is too big")
	}
	return new(big.Int).Exp(a, b, nil)
}

func Lean_nat_pow(a, b V) V { return natValue(integerPow(natBig(a), natBig(b))) }
func Lean_int_pow(a, b V) V { return intValue(integerPow(intBig(a), natBig(b))) }

func Lean_nat_powmod(a, b, modulus V) V {
	if modulus == (V{}) {
		return Lean_nat_pow(a, b)
	}
	return natValue(new(big.Int).Exp(natBig(a), natBig(b), natBig(modulus)))
}

func Lean_nat_gcd(a, b V) V {
	return natValue(new(big.Int).GCD(nil, nil, natBig(a), natBig(b)))
}

func Lean_nat_lcm(a, b V) V {
	if a == (V{}) || b == (V{}) {
		return V{}
	}
	x, y := natBig(a), natBig(b)
	gcd := new(big.Int).GCD(nil, nil, x, y)
	return natValue(gcd.Mul(gcd.Quo(x, gcd), y))
}

func Lean_nat_to_int(a V) V { return a }

func Lean_int_to_nat(a V) V {
	if a.p == nil {
		return V{n: uint64(max(0, int64(a.n)))}
	}
	if intBig(a).Sign() < 0 {
		Lean_dec(a)
		return V{}
	}
	return a
}

func Lean_int_neg_succ_of_nat(a V) V {
	if a.p == nil {
		return V{n: ^a.n}
	}
	value := intValue(new(big.Int).Not(natBig(a)))
	Lean_dec(a)
	return value
}

func Lean_nat_abs(a V) V {
	if Lean_int_dec_nonneg(a) != 0 {
		Lean_inc(a)
		return a
	}
	return natValue(new(big.Int).Abs(intBig(a)))
}

func Lean_int_neg(a V) V {
	if a.p == nil && int64(a.n) != math.MinInt64 {
		return IntFromInt64(-int64(a.n))
	}
	return intValue(new(big.Int).Neg(intBig(a)))
}

func Lean_int_add(a, b V) V {
	if a.p == nil && b.p == nil {
		sum := a.n + b.n
		if int64((sum^a.n)&(sum^b.n)) >= 0 {
			return V{n: sum}
		}
	}
	return intAddBig(a, b)
}

func intAddBig(a, b V) V { return intValue(new(big.Int).Add(intBig(a), intBig(b))) }

func Lean_int_sub(a, b V) V {
	if a.p == nil && b.p == nil {
		diff := a.n - b.n
		if int64((a.n^b.n)&(diff^a.n)) >= 0 {
			return V{n: diff}
		}
	}
	return intSubBig(a, b)
}

func intSubBig(a, b V) V { return intValue(new(big.Int).Sub(intBig(a), intBig(b))) }

func absBits(n uint64) uint64 {
	if int64(n) < 0 {
		return -n
	}
	return n
}

func Lean_int_mul(a, b V) V {
	if a.p == nil && b.p == nil {
		hi, lo := bits.Mul64(absBits(a.n), absBits(b.n))
		if hi == 0 {
			if int64(a.n^b.n) < 0 && lo <= uint64(1)<<63 {
				return V{n: -lo}
			}
			if lo <= math.MaxInt64 {
				return V{n: lo}
			}
		}
	}
	return intValue(new(big.Int).Mul(intBig(a), intBig(b)))
}

func Lean_int_div(a, b V) V {
	if b == (V{}) {
		return V{}
	}
	if a.p == nil && b.p == nil && (int64(a.n) != math.MinInt64 || int64(b.n) != -1) {
		return IntFromInt64(int64(a.n) / int64(b.n))
	}
	return intValue(new(big.Int).Quo(intBig(a), intBig(b)))
}

func Lean_int_div_exact(a, b V) V { return Lean_int_div(a, b) }

func Lean_int_mod(a, b V) V {
	if b == (V{}) {
		Lean_inc(a)
		return a
	}
	if a.p == nil && b.p == nil {
		return IntFromInt64(int64(a.n) % int64(b.n))
	}
	return intValue(new(big.Int).Rem(intBig(a), intBig(b)))
}

func Lean_int_ediv(a, b V) V {
	if b == (V{}) {
		return V{}
	}
	return intValue(new(big.Int).Div(intBig(a), intBig(b)))
}

func Lean_int_emod(a, b V) V {
	if b == (V{}) {
		Lean_inc(a)
		return a
	}
	return intValue(new(big.Int).Mod(intBig(a), intBig(b)))
}

func Lean_int_dec_eq(a, b V) uint8 {
	if a.p == nil || b.p == nil {
		return decision(a == b)
	}
	return decision(intBig(a).Cmp(intBig(b)) == 0)
}

func Lean_int_dec_lt(a, b V) uint8 {
	if a.p == nil && b.p == nil {
		return decision(int64(a.n) < int64(b.n))
	}
	return decision(intBig(a).Cmp(intBig(b)) < 0)
}

func Lean_int_dec_le(a, b V) uint8 {
	if a.p == nil && b.p == nil {
		return decision(int64(a.n) <= int64(b.n))
	}
	return decision(intBig(a).Cmp(intBig(b)) <= 0)
}

func Lean_int_dec_nonneg(a V) uint8 {
	if a.p == nil {
		return decision(int64(a.n) >= 0)
	}
	return decision(intBig(a).Sign() >= 0)
}

func Lean_int_land(a, b V) V {
	if a.p == nil && b.p == nil {
		return V{n: a.n & b.n}
	}
	return intValue(new(big.Int).And(intBig(a), intBig(b)))
}

func Lean_int_lor(a, b V) V {
	if a.p == nil && b.p == nil {
		return V{n: a.n | b.n}
	}
	return intValue(new(big.Int).Or(intBig(a), intBig(b)))
}

func Lean_int_xor(a, b V) V {
	if a.p == nil && b.p == nil {
		return V{n: a.n ^ b.n}
	}
	return intValue(new(big.Int).Xor(intBig(a), intBig(b)))
}

func decision(b bool) uint8 {
	if b {
		return 1
	}
	return 0
}

func NatFromBig(n *big.Int) V { return natValue(new(big.Int).Set(n)) }
func IntFromBig(n *big.Int) V { return intValue(new(big.Int).Set(n)) }
func NatBig(v V) *big.Int     { return new(big.Int).Set(natBig(v)) }
func IntBig(v V) *big.Int     { return new(big.Int).Set(intBig(v)) }
func NatUint64(v V) uint64 {
	if v.p == nil {
		return v.n
	}
	return natBig(v).Uint64()
}
