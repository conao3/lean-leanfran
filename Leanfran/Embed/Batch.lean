import Leanfran.Embed.Types

open Lean System

namespace Leanfran.Embed.Batch

def order (blocks : Array Block) : Array Block := Id.run do
  let mut result := #[]
  let mut done : Std.HashSet String := {}
  let mut pending := blocks.qsort (·.name < ·.name)
  while !pending.isEmpty do
    let ready := pending.filter fun b => b.uses.all fun u => done.contains u || !blocks.any (·.name == u)
    let next := if ready.isEmpty then pending else ready
    for b in next do done := done.insert b.name
    result := result ++ next
    pending := pending.filter (!done.contains ·.name)
  return result

def withOutput (block : Block) (dir : FilePath) : Json :=
  let (key, value) := match block.output with
    | .dir _ => ("output_dir", dir.toString)
    | .file path => ("output_file", (dir / ((FilePath.mk path).fileName.getD path)).toString)
  match block.job with
  | .obj _ => block.job.setObjVal! key (toJson value)
  | _ => Json.mkObj [(key, toJson value)]

def stageDir (ctx : Context) : IO FilePath :=
  return ctx.state / s!"stage-{← IO.Process.getPID}"

partial def filesUnder (dir : FilePath) : IO (Array String) := do
  unless ← dir.isDir do return #[]
  let mut files := #[]
  for path in ← dir.walkDir do
    if (← path.symlinkMetadata).type == .file then
      if let some relative := relativeTo dir path then files := files.push relative
  return files.qsort (· < ·)

def run (job : Block → FilePath → Json) (generateArgs : Array String) (ctx : Context) (blocks : Array Block) :
    IO (Except Failure (Array Generated)) := do
  if blocks.isEmpty then return .ok #[]
  let stage ← stageDir ctx
  let blocks := order blocks
  let mut jobs := #[]
  for (block, i) in blocks.zipIdx do
    let out := stage / toString i
    IO.FS.createDirAll out
    jobs := jobs.push (job block out)
  let batch := stage / "batch.json"
  IO.FS.writeFile batch (Json.arr jobs).pretty
  let args := #["env", ctx.app.toString, "--lang", ctx.lang, "module", "generate", "--batch", batch.toString,
    "--output", "json"] ++ generateArgs
  let child ← match ← (IO.Process.output {cmd := ctx.lake, args, cwd := some ctx.workspace}).toBaseIO with
    | .ok child => pure child
    | .error error => return .error (.environment s!"could not run {ctx.lake}: {error}")
  let results ← match Json.parse child.stdout >>= (·.getArr?) with
    | .ok results => pure results
    | .error _ =>
      return .error (.environment s!"{child.stderr}{ctx.lake} env leanfran --lang {ctx.lang} module generate exited with {child.exitCode}")
  unless child.stderr.isEmpty do IO.eprint child.stderr
  let mut generated := #[]
  for (block, i) in blocks.zipIdx do
    let summary := results[i]?.getD Json.null
    if let .ok message := (summary.getObjValD "error").getStr? then
      let code := (summary.getObjValAs? Nat "code").toOption.getD 255
      return .error {code := if code == 254 then 254 else 255, message := s!"{block.name}: {message}"}
    for skipped in (summary.getObjValD "skipped").getArr?.toOption.getD #[] do
      let name := (skipped.getObjValD "name").getStr?.toOption.getD ""
      let reason := (skipped.getObjValD "reason").getStr?.toOption.getD ""
      IO.eprintln s!"leanfran: skipped {name}: {reason}"
    let out := stage / toString i
    generated := generated.push {block := block.name, stage := out, files := ← filesUnder out, summary}
  unless child.exitCode == 0 do
    return .error (.environment s!"{ctx.lake} env leanfran --lang {ctx.lang} module generate exited with {child.exitCode}")
  return .ok generated

end Leanfran.Embed.Batch
