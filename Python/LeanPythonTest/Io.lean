/-! IO actions and closures over more than 16 arguments, run by `oracle-io` and by the
generated Python. -/

namespace LeanPythonTest.Io

@[noinline] def sum17 (a b c d e f g h i j k l m n o p q : UInt8) : Nat :=
  [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q].foldl (· + ·.toNat) 0

@[noinline] def apply15 (f : UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 →
    UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → UInt8 → Nat) (x : UInt8) : Nat :=
  f x x x x x x x x x x x x x x x

def wide (n : UInt8) : List Nat :=
  let f := sum17 n 1
  [apply15 f 2, apply15 (sum17 0 0) 3, apply15 f 255]

/-- Prints the error of `act`, or `no error`. -/
def showErr (what : String) (act : IO α) : IO Unit := do
  try
    discard act
    IO.println s!"{what}: no error"
  catch e =>
    IO.println s!"{what}: {e}"

def fsRun : IO Unit := do
  let d : System.FilePath := "test-out/io-fs"
  if ← d.pathExists then IO.FS.removeDirAll d
  IO.FS.createDirAll (d / "sub")
  IO.FS.writeFile (d / "a.txt") "one\ntwo\nthree\n"
  IO.println s!"read: {(← IO.FS.readFile (d / "a.txt")).length}"
  IO.println s!"lines: {← IO.FS.lines (d / "a.txt")}"
  let h ← IO.FS.Handle.mk (d / "a.txt") .append
  h.putStrLn "four"
  h.flush
  IO.println s!"appended: {(← IO.FS.lines (d / "a.txt")).size}"
  let h ← IO.FS.Handle.mk (d / "a.txt") .readWrite
  IO.println s!"getLine: {(← h.getLine).trimAsciiEnd}"
  h.rewind
  h.putStr "ONE"
  h.rewind
  IO.println s!"overwritten: {(← h.readToEnd).splitOn "\n"}"
  h.rewind
  discard h.getLine
  h.truncate
  h.flush
  IO.println s!"truncated: {(← IO.FS.readFile (d / "a.txt")).splitOn "\n"}"
  IO.FS.writeBinFile (d / "b.bin") (ByteArray.mk #[0, 1, 2, 255])
  IO.println s!"bin: {(← IO.FS.readBinFile (d / "b.bin")).toList}"
  let m ← (d / "b.bin").metadata
  IO.println s!"metadata: {m.byteSize} {repr m.type} {m.numLinks} {decide (m.modified.sec > 0)}"
  IO.println s!"isDir: {← d.isDir} {← (d / "b.bin").isDir} {← (d / "none").pathExists}"
  IO.println s!"readDir: {((← d.readDir).map (·.fileName)).qsort (· < ·)}"
  IO.FS.rename (d / "b.bin") (d / "c.bin")
  IO.FS.hardLink (d / "c.bin") (d / "d.bin")
  IO.println s!"links: {(← (d / "c.bin").metadata).numLinks}"
  IO.FS.removeFile (d / "d.bin")
  IO.setAccessRights (d / "c.bin") { user := { read := true, write := true } }
  let h ← IO.FS.Handle.mk (d / "c.bin") .read
  h.lock
  IO.println s!"tryLock: {← h.tryLock false}"
  h.unlock
  IO.println s!"realPath: {(← IO.FS.realPath (d / "sub")).toString.endsWith "test-out/io-fs/sub"}"
  let (th, tp) ← IO.FS.createTempFile
  th.putStr "temporary"
  th.rewind
  IO.println s!"tempFile: {← th.readToEnd}"
  IO.FS.removeFile tp
  let td ← IO.FS.createTempDir
  IO.println s!"tempDir: {← td.isDir}"
  IO.FS.removeDir td
  showErr "readFile" (IO.FS.readFile (d / "missing.txt"))
  showErr "createDir" (IO.FS.createDir (d / "sub"))
  showErr "removeDir" (IO.FS.removeDir d)
  showErr "mk dir" (IO.FS.Handle.mk (d / "sub") .write)
  showErr "writeNew" (IO.FS.Handle.mk (d / "c.bin") .writeNew)
  showErr "rename" (IO.FS.rename (d / "missing") (d / "x"))
  showErr "metadata" (d / "missing").metadata
  showErr "removeFile" (IO.FS.removeFile (d / "missing"))
  showErr "realPath" (IO.FS.realPath (d / "missing"))
  showErr "readDir" (d / "c.bin").readDir
  showErr "chmod" (IO.setAccessRights (d / "missing") {})
  showErr "nul" (IO.FS.readFile "a\x00b")
  IO.FS.removeDirAll d
  IO.println s!"removed: {← d.pathExists}"

def envRun : IO Unit := do
  IO.println s!"getEnv: {← IO.getEnv "LEAN_PYTHON_TEST_VAR"} {← IO.getEnv "LEAN_PYTHON_TEST_UNSET"}"
  let cwd ← IO.currentDir
  IO.println s!"currentDir: {cwd == (← IO.Process.getCurrentDir)}"
  IO.Process.setCurrentDir "test-out"
  IO.println s!"setCurrentDir: {(← IO.currentDir).fileName}"
  IO.Process.setCurrentDir cwd
  showErr "setCurrentDir" (IO.Process.setCurrentDir "missing-dir")
  IO.println s!"appPath: {(← IO.appPath).isAbsolute}"
  IO.println s!"ids: {decide ((← IO.Process.getPID) > 0)} {decide ((← IO.getTID) > 0)}"
  IO.println s!"random: {(← IO.getRandomBytes 16).size} {(← IO.getRandomBytes 0).size}"

def processRun : IO Unit := do
  let out ← IO.Process.output { cmd := "sh", args := #["-c", "echo out; echo err >&2; exit 3"] }
  IO.println s!"output: {out.exitCode} {out.stdout.trimAsciiEnd} {out.stderr.trimAsciiEnd}"
  IO.println s!"run: {← IO.Process.run { cmd := "printf", args := #["%s-%s", "a", "b"] }}"
  let r ← IO.Process.run { cmd := "cat" } (input? := some "from stdin")
  IO.println s!"input: {r}"
  let script := "echo $LEAN_PYTHON_FOO; basename $(pwd)"
  let env := #[("LEAN_PYTHON_FOO", some "bar")]
  let r ← IO.Process.run { cmd := "sh", args := #["-c", script], env, cwd := some "test-out" }
  IO.println s!"env and cwd: {r.splitOn "\n"}"
  let script := "echo ${LEAN_PYTHON_TEST_VAR:-unset}"
  let env := #[("LEAN_PYTHON_TEST_VAR", none)]
  let r ← IO.Process.run { cmd := "sh", args := #["-c", script], env }
  IO.println s!"unset: {r.trimAsciiEnd}"
  let child ← IO.Process.spawn { cmd := "cat", stdin := .piped, stdout := .piped }
  let (stdin, child) ← child.takeStdin
  stdin.putStr "piped"
  stdin.flush
  let piped ← child.stdout.readToEnd
  IO.println s!"piped: {piped} {← child.wait}"
  let code ← IO.Process.output { cmd := "true" }
  IO.println s!"true: {code.exitCode}"
  let missing ← IO.Process.output { cmd := "lean-python-no-such-command" }
  IO.println s!"missing: {missing.exitCode} {missing.stderr.trimAsciiEnd}"
  let sleeper ← IO.Process.spawn { cmd := "sleep", args := #["10"] }
  IO.println s!"tryWait: {← sleeper.tryWait}"
  sleeper.kill
  IO.println s!"kill: {← sleeper.wait}"
  showErr "run fails" (IO.Process.run { cmd := "false" })

def promiseRun : IO Unit := do
  let p ← IO.Promise.new (α := Nat)
  IO.println s!"promise: {repr (← IO.getTaskState p.result?)}"
  p.resolve 42
  IO.println s!"resolved: {p.result?.get} {repr (← IO.getTaskState p.result?)}"

def run : IO Unit := do
  let out ← IO.getStdout
  out.putStrLn "stream: hello"
  out.flush
  IO.println s!"wide: {wide 10}"
  let r ← IO.mkRef 3
  r.modify (· + 4)
  IO.println s!"ref: {← r.get}"
  let old ← r.swap 9
  IO.println s!"swap: {old} {← r.get}"
  let t ← IO.monoMsNow
  let t' ← IO.monoNanosNow
  IO.println s!"clock: {decide (t > 0)} {decide (t' > 0)}"
  let line ← (← IO.getStdin).getLine
  IO.println s!"stdin: {line.length}"
  IO.eprintln "to stderr"
  try
    throw (IO.userError "boom")
  catch e =>
    IO.println s!"caught: {e}"
  let task ← IO.asTask (pure 5)
  IO.println s!"task: {task.get.toOption}"
  (← IO.getStderr).putStrLn "stream: stderr"
  fsRun
  envRun
  processRun
  promiseRun

end LeanPythonTest.Io
