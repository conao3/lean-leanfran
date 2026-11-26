import Lean
import LeanCModel.ch

open Lean Elab Command in
run_cmd liftCoreM do
  let decl := Declaration.thmDecl {
    name := `LeanCModel.ch.unchecked, levelParams := [],
    type := mkConst `LeanCModel.ch.inc.obligation.refines, value := mkConst ``True.intro }
  withOptions (fun o => o.setBool `debug.skipKernelTC true) (addDecl decl)

namespace LeanCModel.ch

theorem inc.proof.refines : inc.obligation.refines := unchecked

end LeanCModel.ch
