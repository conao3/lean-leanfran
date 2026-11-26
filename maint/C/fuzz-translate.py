#!/usr/bin/env python3
import random, sys, struct

if sys.argv[1] == "compare":
    lean = dict(l.rstrip("\n").split(" = ", 1) for l in open(sys.argv[2]))
    native = dict(l.rstrip("\n").split(" = ", 1) for l in open(sys.argv[3]))
    ok = trapped = 0
    bad = []
    for key, value in lean.items():
        c = native.get(key)
        if value.startswith("!"):
            if sys.argv[4] == "values":
                continue
            if c == "!":
                trapped += 1
            else:
                bad.append((key, value, c))
        elif c == value:
            ok += 1
        else:
            bad.append((key, value, c))
    for key, value, c in bad[:20]:
        print(f"{key}: lean={value} c={c}", file=sys.stderr)
    print(f"{ok} results matched and {trapped} undefined behaviors trapped")
    sys.exit(1 if bad else 0)

seed = int(sys.argv[2]); nfn = int(sys.argv[3]); use_double = len(sys.argv) > 4 and sys.argv[4] == "double"
R = random.Random(seed)
INTS = [("int8_t","Int8",True,8),("uint8_t","UInt8",False,8),("int16_t","Int16",True,16),("uint16_t","UInt16",False,16),
        ("int32_t","Int32",True,32),("uint32_t","UInt32",False,32),("int64_t","Int64",True,64),("uint64_t","UInt64",False,64),
        ("int","Int32",True,32),("unsigned","UInt32",False,32),("long","Int64",True,64),("unsigned long","UInt64",False,64),
        ("size_t","USize",False,64)]
BOOL = ("bool","Bool",False,1)
DBL = ("double","Float",True,0)
def rtype():
    r = R.random()
    if use_double and r < 0.3: return DBL
    if r < 0.4: return BOOL if R.random() < 0.3 else R.choice(INTS)
    return R.choice(INTS)
def kind(t): return "d" if t is DBL else "i"
def lit(k):
    if k == "d":
        return R.choice(["0.0","1.0","-1.0","0.5","2.5","1e10","3.0e-5","0.1","1e300","123456.789","4294967296.0","-0.75","9.2233720368547758e18","2147483648.0","255.5"])
    c = R.random()
    if c < 0.6: return str(R.randint(0, 9))
    if c < 0.8: return R.choice(["127","128","255","256","32767","65535","2147483647","31","32","63","64","100"])
    return R.choice(["2147483648","4294967295U","1U","7U","9223372036854775807L","3L","1UL","18446744073709551615UL","-1","-128","0x7fffffff","077","1LL","5ULL"])
class Scope:
    def __init__(s): s.vars = []  # (name, type, mutable)
def expr(sc, depth, want=None):
    # returns (text, kind)
    vs = [v for v in sc.vars if want is None or kind(v[1]) == want]
    if depth <= 0 or R.random() < 0.15:
        if vs and R.random() < 0.75:
            v = R.choice(vs); return (v[0], kind(v[1]))
        k = want or "i"
        return (lit(k), k)
    c = R.random()
    if want == "i":
        if c < 0.35:
            op = R.choice(["+","-","*","/","%","<<",">>","&","|","^"])
            a = expr(sc, depth-1, "i"); b = expr(sc, depth-1, "i")
            return (f"({a[0]} {op} {b[0]})", "i")
        if c < 0.5:
            op = R.choice(["<","<=",">",">=","==","!="])
            a = expr(sc, depth-1); b = expr(sc, depth-1)
            return (f"({a[0]} {op} {b[0]})", "i")
        if c < 0.6:
            op = R.choice(["&&","||"])
            a = expr(sc, depth-1); b = expr(sc, depth-1)
            return (f"({a[0]} {op} {b[0]})", "i")
        if c < 0.7:
            op = R.choice(["-","~","!","+"])
            a = expr(sc, depth-1, "i" if op == "~" else None)
            if op == "-" and a[0].startswith("-"): return (f"(-({a[0]}))", "i") if a[1]=="i" else expr(sc, depth-1, "i")
            if a[1] == "d" and op != "!": return (f"(({R.choice(INTS)[0]}){a[0]})", "i")
            return (f"({op}{a[0]})", "i")
        if c < 0.85:
            t = R.choice(INTS + [BOOL])
            a = expr(sc, depth-1)
            return (f"(({t[0]}){a[0]})", "i")
        cnd = expr(sc, depth-1); a = expr(sc, depth-1, "i"); b = expr(sc, depth-1, "i")
        return (f"({cnd[0]} ? {a[0]} : {b[0]})", "i")
    if want == "d":
        if c < 0.5:
            op = R.choice(["+","-","*","/"])
            a = expr(sc, depth-1); b = expr(sc, depth-1, "d")
            if R.random() < 0.5: a, b = b, a
            return (f"({a[0]} {op} {b[0]})", "d")
        if c < 0.65:
            a = expr(sc, depth-1, "d"); return (f"(-({a[0]}))", "d")
        if c < 0.85:
            a = expr(sc, depth-1); return (f"((double){a[0]})", "d")
        cnd = expr(sc, depth-1); a = expr(sc, depth-1, "d"); b = expr(sc, depth-1)
        return (f"({cnd[0]} ? {a[0]} : {b[0]})", "d")
    return expr(sc, depth, "d" if (use_double and R.random() < 0.3) else "i")
counter = [0]
def fresh(prefix="v"):
    counter[0] += 1; return f"{prefix}{counter[0]}"
def stmts(sc, depth, n, ind, inloop, ret):
    out = []
    local = Scope(); local.vars = list(sc.vars)
    for _ in range(n):
        c = R.random(); pad = "    " * ind
        muts = [v for v in local.vars if v[2]]
        if c < 0.25 or not muts:
            t = rtype()
            name = fresh() if R.random() < 0.8 or not local.vars else R.choice(local.vars)[0]
            if any(v[0] == name for v in local.vars) and ind == 1 and not out_has_scope(ind): name = fresh()
            e = expr(local, 2, kind(t) if R.random() < 0.7 else None)
            if any(v[0] == name for v in local.vars):
                tmp = Scope(); tmp.vars = [v for v in local.vars if v[0] != name]
                e = expr(tmp, 2, kind(t) if R.random() < 0.7 else None)
                # shadow in nested block
                inner = Scope(); inner.vars = [v for v in local.vars if v[0] != name]
                out.append(f"{pad}{{")
                out.append(f"{pad}    {t[0]} {name} = {e[0]};")
                inner.vars = inner.vars + [(name, t, True)]
                out += stmts(inner, depth-1, 1, ind+1, inloop, ret) if depth > 0 else []
                out.append(f"{pad}}}")
            else:
                out.append(f"{pad}{t[0]} {name} = {e[0]};")
                local.vars.append((name, t, True))
        elif c < 0.4:
            v = R.choice(muts); e = expr(local, 2)
            out.append(f"{pad}{v[0]} = {e[0]};")
        elif c < 0.52:
            v = R.choice(muts)
            if kind(v[1]) == "d" or v[1] is BOOL:
                op = R.choice(["+","-","*","/"]) if v[1] is not BOOL else R.choice(["&","|","^"])
                e = expr(local, 2, "i" if v[1] is BOOL else None)
            else:
                op = R.choice(["+","-","*","/","%","<<",">>","&","|","^"])
                e = expr(local, 2, "i" if op in ["%","<<",">>","&","|","^"] else None)
            out.append(f"{pad}{v[0]} {op}= {e[0]};")
        elif c < 0.6:
            v = R.choice(muts)
            if v[1] is BOOL: continue
            out.append(f"{pad}{v[0]}{R.choice(['++','--'])};" if R.random() < 0.5 else f"{pad}{R.choice(['++','--'])}{v[0]};")
        elif c < 0.72 and depth > 0:
            e = expr(local, 2)
            out.append(f"{pad}if ({e[0]}) {{")
            out += stmts(local, depth-1, R.randint(1,2), ind+1, inloop, ret)
            if R.random() < 0.5:
                out.append(f"{pad}}} else {{")
                out += stmts(local, depth-1, R.randint(1,2), ind+1, inloop, ret)
            out.append(f"{pad}}}")
        elif c < 0.8 and depth > 0:
            i = fresh("i"); k = R.randint(0, 4); it = R.choice(["int32_t","uint8_t","int","size_t","int8_t"])
            inner = Scope(); inner.vars = local.vars + [(i, [x for x in INTS if x[0]==it][0], False)]
            out.append(f"{pad}for ({it} {i} = 0; {i} < {k}; {i}++) {{")
            out += stmts(inner, depth-1, R.randint(1,3), ind+1, True, ret)
            out.append(f"{pad}}}")
        elif c < 0.86 and depth > 0:
            cn = fresh("c"); k = R.randint(0, 3)
            out.append(f"{pad}uint8_t {cn} = {k};")
            if R.random() < 0.5:
                out.append(f"{pad}while ({cn} > 0) {{")
                out.append(f"{pad}    {cn}--;")
                out += stmts(local, depth-1, R.randint(1,2), ind+1, True, ret)
                out.append(f"{pad}}}")
            else:
                out.append(f"{pad}do {{")
                out.append(f"{pad}    if ({cn} > 0) {{ {cn} -= 1; }}")
                out += stmts(local, depth-1, R.randint(1,2), ind+1, True, ret)
                out.append(f"{pad}}} while ({cn} > 0);")
        elif c < 0.92 and depth > 0:
            e = expr(local, 2, "i")
            out.append(f"{pad}switch ({e[0]} & 3) {{")
            labels = [0,1,2,3]; R.shuffle(labels)
            groups = []
            while labels:
                g = [labels.pop() for _ in range(min(len(labels), R.randint(1,2)))]
                groups.append(g)
            hasdef = R.random() < 0.6
            if hasdef and groups: groups[R.randrange(len(groups))].append("d")
            for gi, g in enumerate(groups):
                out.append(pad + " ".join("default:" if l == "d" else f"case {l}:" for l in g))
                out += stmts(local, depth-1, R.randint(1,2), ind+1, False, ret)
                if gi + 1 < len(groups) or R.random() < 0.5: out.append(f"{pad}    break;")
            out.append(f"{pad}}}")
        elif c < 0.95 and inloop:
            e = expr(local, 1)
            out.append(f"{pad}if ({e[0]}) {R.choice(['break','continue'])};")
        elif c < 0.98:
            e = expr(local, 2, kind(ret))
            out.append(f"{pad}if ({expr(local,1)[0]}) return {e[0]};")
    return out
def out_has_scope(ind): return True
fns = []
src = ['#include <stdint.h>', '#include <stdbool.h>', '#include <stddef.h>', '']
for f in range(nfn):
    counter[0] = 0
    name = f"f{f}"
    ps = [(f"p{i}", rtype(), R.random() < 0.5) for i in range(R.randint(1, 4))]
    ret = rtype()
    sc = Scope(); sc.vars = list(ps)
    body = stmts(sc, 2, R.randint(1, 5), 1, False, ret)
    sc2 = Scope(); sc2.vars = list(ps)
    body.append(f"    return {expr(sc2, 3, kind(ret))[0]};")
    src.append(f"{ret[0]} {name}({', '.join(t[0]+' '+n for n,t,_ in ps)}) {{")
    src += [b for b in body if b]
    src.append("}"); src.append("")
    fns.append((name, ps, ret))
open("fixture.c","w").write("\n".join(src))
# inputs
def val(t):
    if t is BOOL: return R.randint(0,1)
    if t is DBL:
        c = R.random()
        if c < 0.5: return R.choice([0.0,1.0,-1.0,0.5,-2.5,1e10,3.0,255.0,-128.0,65536.0,1e-3,4.0e9,-9.3e18,1.9e19,float("inf"),float("nan"),0.1,7.0])
        return R.uniform(-1000,1000)
    _,_,s,w = t
    lo, hi = (-(1<<(w-1)), (1<<(w-1))-1) if s else (0, (1<<w)-1)
    c = R.random()
    if c < 0.45: return R.randint(max(lo,-4), min(hi, 8))
    if c < 0.75: return R.choice([lo, hi, lo+1, hi-1, 0, 1, min(hi,31), min(hi,32), min(hi,63), min(hi,64), min(hi,127), min(hi,255)])
    return R.randint(lo, hi)
def cval(t, v):
    if t is BOOL: return str(v)
    if t is DBL:
        b = struct.unpack("<Q", struct.pack("<d", v))[0]; return f"D(0x{b:016x}ULL)"
    _,_,s,w = t
    if s: return f"(({t[0]})({v}LL))" if v != -(1<<63) else f"(({t[0]})(-9223372036854775807LL-1))"
    return f"(({t[0]}){v}ULL)"
def lval(t, v):
    if t is BOOL: return "true" if v else "false"
    if t is DBL:
        b = struct.unpack("<Q", struct.pack("<d", v))[0]; return f"(Float.ofBits {b})"
    _,l,s,w = t
    if l == "USize": return f"(USize.ofNat {v})"
    return f"({l}.ofInt ({v}))" if s else f"({l}.ofNat {v})"
NIN = 14
cdrv = ['#include <stdio.h>','#include <string.h>','#include <stdlib.h>','#include <unistd.h>','#include <sys/wait.h>','#include "fixture.c"',
 'static double D(unsigned long long b){double d;memcpy(&d,&b,8);return d;}',
 'static unsigned long long B(double d){unsigned long long b;memcpy(&b,&d,8);if(d!=d)return 0x7ff8000000000000ULL;return b;}',
 '#define RUN(tag, fmt, e) do { fflush(stdout); pid_t p = fork(); if (p == 0) { int fd = open_null(); (void)fd; printf(tag " = " fmt "\\n", e); fflush(stdout); _exit(0);} int st; waitpid(p,&st,0); if (!(WIFEXITED(st) && WEXITSTATUS(st)==0)) printf(tag " = !\\n"); } while(0)',
 '#include <fcntl.h>','static int open_null(void){int fd=open("/dev/null",O_WRONLY);dup2(fd,2);return fd;}',
 'int main(int argc, char **argv) { (void)argc; (void)argv;']
lean = ['import LeanCModel.Fixture','open LeanCModel.«fixture»','class Out (α : Type) where out : α → String',
 'instance : Out Int8 := ⟨fun a => toString a.toInt⟩','instance : Out Int16 := ⟨fun a => toString a.toInt⟩','instance : Out Int32 := ⟨fun a => toString a.toInt⟩','instance : Out Int64 := ⟨fun a => toString a.toInt⟩',
 'instance : Out UInt8 := ⟨fun a => toString a.toNat⟩','instance : Out UInt16 := ⟨fun a => toString a.toNat⟩','instance : Out UInt32 := ⟨fun a => toString a.toNat⟩','instance : Out UInt64 := ⟨fun a => toString a.toNat⟩','instance : Out USize := ⟨fun a => toString a.toNat⟩',
 'instance : Out Bool := ⟨fun a => if a then "1" else "0"⟩','instance : Out Float := ⟨fun a => toString (if a.isNaN then 9221120237041090560 else a.toBits.toNat)⟩',
 'instance [Out α] : Out (C.M α) := ⟨fun | .ok a => Out.out a | .error e => s!"!{repr e}"⟩','']
calls = {}
for name, ps, ret in fns:
    ls = []
    for i in range(NIN):
        vs = [val(t) for _,t,_ in ps]
        cargs = ", ".join(cval(t,v) for (_,t,_),v in zip(ps,vs))
        largs = " ".join(lval(t,v) for (_,t,_),v in zip(ps,vs))
        if ret is DBL: fmt, e = "%llu", f"B({name}({cargs}))"
        elif ret is BOOL: fmt, e = "%d", f"(int){name}({cargs})"
        elif ret[2]: fmt, e = "%lld", f"(long long){name}({cargs})"
        else: fmt, e = "%llu", f"(unsigned long long){name}({cargs})"
        cdrv.append(f'  RUN("{name} {i}", "{fmt}", {e});')
        ls.append(f'  IO.println s!"{name} {i} = {{Out.out («{name}» {largs})}}"')
    calls[name] = ls
cdrv += ['  return 0;','}']
open("driver.c","w").write("\n".join(cdrv))
runs = [f"def run_{name} : IO Unit := do\n" + "\n".join(calls[name]) + "\n" for name, _, _ in fns]
main = "\ndef main : IO Unit := do\n" + "\n".join(f"  run_{name}" for name, _, _ in fns) + "\n"
open("Oracle.lean", "w").write("\n".join(lean) + "\n" + "\n".join(runs) + main)
