import LeanPhp

open Lean Lean.IR

namespace LeanPhpTest.ControlCoverage

def exprKind : IR.Expr → Name
  | .ctor .. => `Lean.IR.Expr.ctor
  | .reset .. => `Lean.IR.Expr.reset
  | .reuse .. => `Lean.IR.Expr.reuse
  | .proj .. => `Lean.IR.Expr.proj
  | .uproj .. => `Lean.IR.Expr.uproj
  | .sproj .. => `Lean.IR.Expr.sproj
  | .fap .. => `Lean.IR.Expr.fap
  | .pap .. => `Lean.IR.Expr.pap
  | .ap .. => `Lean.IR.Expr.ap
  | .box .. => `Lean.IR.Expr.box
  | .unbox .. => `Lean.IR.Expr.unbox
  | .lit .. => `Lean.IR.Expr.lit
  | .isShared .. => `Lean.IR.Expr.isShared

def bodyKind : FnBody → Name
  | .vdecl .. => `Lean.IR.FnBody.vdecl
  | .jdecl .. => `Lean.IR.FnBody.jdecl
  | .set .. => `Lean.IR.FnBody.set
  | .setTag .. => `Lean.IR.FnBody.setTag
  | .uset .. => `Lean.IR.FnBody.uset
  | .sset .. => `Lean.IR.FnBody.sset
  | .inc .. => `Lean.IR.FnBody.inc
  | .dec .. => `Lean.IR.FnBody.dec
  | .del .. => `Lean.IR.FnBody.del
  | .case .. => `Lean.IR.FnBody.case
  | .ret .. => `Lean.IR.FnBody.ret
  | .jmp .. => `Lean.IR.FnBody.jmp
  | .unreachable => `Lean.IR.FnBody.unreachable

partial def collectKinds (body : FnBody) (kinds : Std.HashSet Name) : Std.HashSet Name :=
  let kinds := kinds.insert (bodyKind body)
  match body with
  | .vdecl _ _ e k => collectKinds k (kinds.insert (exprKind e))
  | .jdecl _ _ b k => collectKinds k (collectKinds b kinds)
  | .case _ _ _ alts => alts.foldl (fun acc alt => collectKinds alt.body acc) kinds
  | .ret .. | .jmp .. | .unreachable => kinds
  | b => collectKinds b.body kinds

def fixtureName (n : Name) : String :=
  ".".intercalate ((n.toString.splitOn ".").drop 1 |>.takeWhile (!·.startsWith "_"))

end LeanPhpTest.ControlCoverage

open LeanPhpTest.ControlCoverage

def main (args : List String) : IO UInt32 := do
  let moduleName :: roots := args | throw (IO.userError "Expected MODULE ROOT ...")
  let module := moduleName.toName
  initSearchPath (← findSysroot)
  let env ← importModules #[{ module := `Lean }, { module }] {} (trustLevel := 1024)
  let roots := roots.toArray.map String.toName
  let inits := LeanPhp.initializers env module
  let .ok decls := LeanPhp.collect env (LeanPhp.exportedFns env)
    (roots ++ roots.map (LeanPhp.csimpTarget env) ++ inits.roots) |
      throw (IO.userError "Could not collect fixture IR.")
  let mut covered : Std.HashMap Name (Std.HashSet String) := {}
  for decl in decls do
    if !(`LeanPhpTest).isPrefixOf decl.name || inits.globals.contains decl.name then continue
    if let .fdecl name _ _ body _ := decl then
      for kind in collectKinds body {} do
        covered := covered.alter kind fun names => some ((names.getD {}).insert (fixtureName name))
  let mut missing := 0
  let mut total := 0
  for type in [``Lean.IR.Expr, ``Lean.IR.FnBody] do
    let some (.inductInfo info) := env.find? type | throw (IO.userError s!"Missing type {type}.")
    for kind in info.ctors do
      total := total + 1
      if let some entries := covered[kind]? then
        IO.println s!"{kind}: covered by {", ".intercalate (entries.toList.mergeSort)}"
      else
        missing := missing + 1
        IO.eprintln s!"{kind}: MISSING"
  IO.println s!"IR coverage: {total - missing}/{total} constructors"
  return if missing == 0 then 0 else 1
