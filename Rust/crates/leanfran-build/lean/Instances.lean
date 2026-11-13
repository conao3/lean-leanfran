import Lean

/-! # Instantiations of polymorphic functions for Rust

`rust_instances f [Nat, String]` defines `f.inst_Nat := @f Nat _` and `f.inst_String`, with the
instance arguments synthesized, and records them in `rustInstancesExt`. `leanfran module
generate` turns the instantiations into one generic Rust function dispatching through a sealed
trait implemented for the instantiated types. A function with several type parameters takes
named arguments: `rust_instances g [(α := Nat) (β := String), (α := Int) (β := Bool)]`. -/

open Lean Elab Command Meta

namespace LeanRust

/-- An instantiation: the polymorphic function, the definition specialized to the type
    arguments, and the type arguments by parameter name, in the order of the parameters. -/
abbrev RustInstance := Name × Name × Array (Name × Expr)

initialize rustInstancesExt : SimplePersistentEnvExtension RustInstance (Array RustInstance) ←
  registerSimplePersistentEnvExtension {
    name := `LeanRust.rustInstancesExt
    addEntryFn := Array.push
    addImportedFn := fun _ => #[]
  }

declare_syntax_cat rustInstance
syntax rustNamedArg := "(" ident " := " term ")"
syntax (name := rustInstanceNamed) (priority := high) rustNamedArg+ : rustInstance
syntax (name := rustInstanceType) term : rustInstance

syntax (name := rustInstances) "rust_instances " ident " [" rustInstance,* "]" : command

/-- The part of a definition name standing for a type: `Nat` → `Nat`, `List Nat` → `List_Nat`,
    `Std.U32` → `U32`. -/
partial def typeSuffix (e : Expr) : MetaM String := do
  let e ← instantiateMVars e
  let fn := e.getAppFn
  let head := match fn with
    | .const c _ => match c with
      | .str _ s => s
      | _ => "T"
    | .sort _ => "Sort"
    | _ => "T"
  let mut parts := #[head]
  for a in e.getAppArgs do
    if (← whnf (← inferType a)).isSort then
      parts := parts.push (← typeSuffix a)
  let s := "_".intercalate parts.toList
  return String.ofList (s.toList.map fun c => if c.isAlphanum || c == '_' then c else '_')

/-- `@f` applied to the type arguments `assign` and to synthesized instances, abstracted over
    the other parameters. -/
partial def instantiateFn (f : Expr) (ty : Expr) (assign : Array (Name × Expr)) (args fvars : Array Expr) :
    MetaM Expr := do
  match ty with
  | .forallE n d b bi =>
    if let some (_, t) := assign.find? (·.1 == n) then
      unless ← isDefEq (← inferType t) d do
        throwError "rust_instances: `{t}` is not of the type `{d}` of the parameter `{n}`"
      instantiateFn f (b.instantiate1 t) assign (args.push t) fvars
    else if bi.isInstImplicit then
      let d ← instantiateMVars d
      let some inst ← synthInstance? d | throwError "rust_instances: cannot synthesize `{d}`"
      instantiateFn f (b.instantiate1 inst) assign (args.push inst) fvars
    else if (← whnf d).isSort then
      throwError "rust_instances: no type is given for the type parameter `{n}`"
    else
      withLocalDecl n bi d fun x => instantiateFn f (b.instantiate1 x) assign (args.push x) (fvars.push x)
  | _ => do
    let v ← mkLambdaFVars fvars (mkAppN f args)
    instantiateMVars v

/-- The names of the type parameters of `ty`, in order. -/
def typeParams (ty : Expr) : MetaM (Array Name) :=
  forallTelescope ty fun xs _ => do
    let mut out := #[]
    for x in xs do
      if (← whnf (← inferType x)).isSort then out := out.push (← x.fvarId!.getUserName)
    return out

@[command_elab rustInstances] def elabRustInstances : CommandElab := fun stx => do
  let fnId := stx[1]
  let items := stx[3].getSepArgs
  liftTermElabM do
    let fn ← realizeGlobalConstNoOverloadWithInfo fnId
    let ci ← getConstInfo fn
    let params ← typeParams ci.type
    for item in items do
      let given : Array (Name × Syntax) ←
        if item.getKind == ``rustInstanceNamed then
          pure (item[0].getArgs.map fun a => (a[1].getId, a[3]))
        else
          let some p := params[0]? | throwErrorAt item "rust_instances: `{fn}` has no type parameter"
          if params.size > 1 then
            throwErrorAt item "rust_instances: `{fn}` has the type parameters {params.toList}; name them: `({p} := ..)`"
          pure #[(p, item[0])]
      let mut typed := #[]
      for (n, t) in given do
        unless params.contains n do throwErrorAt t "rust_instances: `{fn}` has no type parameter `{n}`"
        let e ← Term.elabType t
        Term.synthesizeSyntheticMVarsNoPostponing
        typed := typed.push (n, ← instantiateMVars e)
      let assign := params.filterMap fun p => typed.find? (·.1 == p)
      let lvls ← ci.levelParams.mapM fun _ => mkFreshLevelMVar
      let value ← instantiateFn (mkConst fn lvls) (ci.type.instantiateLevelParams ci.levelParams lvls) assign #[] #[]
      let type ← instantiateMVars (← inferType value)
      if value.hasMVar || type.hasMVar then
        throwErrorAt item "rust_instances: the instantiation of `{fn}` has unassigned universe levels or arguments"
      let suffix := "_".intercalate (← assign.toList.mapM fun (_, t) => typeSuffix t)
      let name := fn.str s!"inst_{suffix}"
      addAndCompile (.defnDecl { name, levelParams := [], type, value, hints := .abbrev, safety := .safe })
      setReducibilityStatus name .reducible
      addDeclarationRangesFromSyntax name item
      modifyEnv (rustInstancesExt.addEntry · (fn, name, assign))

end LeanRust
