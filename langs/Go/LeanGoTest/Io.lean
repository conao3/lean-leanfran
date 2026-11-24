import Std.Time.DateTime.Timestamp

namespace LeanGoTest.Io

private def showError (label : String) (action : IO α) : IO Unit := do
  try
    discard action
    throw (IO.userError s!"unexpected success: {label}")
  catch e =>
    IO.println s!"{label}: {e}"
    if e.toString.startsWith "unexpected success:" then throw e

private def streams : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let stderr ← IO.getStderr
  let line ← stdin.getLine
  let bytes ← stdin.read 3
  let rest ← stdin.getLine
  let eof ← stdin.getLine
  let eofBytes ← stdin.read 8
  stdout.putStrLn s!"stdin: {repr line} {bytes.toList} {repr rest} {eof.isEmpty} {eofBytes.isEmpty}"
  stdout.write (ByteArray.mk #[98, 121, 116, 101, 115, 10])
  stdout.flush
  stderr.putStrLn "to stderr"
  stderr.flush
  IO.println s!"ttys: {← stdin.isTty} {← stdout.isTty} {← stderr.isTty}"
  let h ← IO.FS.Handle.mk "redirect.txt" .write
  let file := IO.FS.Stream.ofHandle h
  let prevOut ← IO.setStdout file
  let prevErr ← IO.setStderr file
  IO.println "redirected stdout"
  IO.eprintln "redirected stderr"
  IO.println (dbgTraceIfShared "debug shared" "persistent")
  discard (IO.setStdout prevOut)
  discard (IO.setStderr prevErr)
  file.flush
  let h ← IO.FS.Handle.mk "initial.txt" .read
  let prevIn ← IO.setStdin (.ofHandle h)
  IO.println s!"redirected stdin: {repr (← (← IO.getStdin).getLine)}"
  discard (IO.setStdin prevIn)
  IO.println s!"trace result: {dbgTrace "debug trace" fun _ => 7}"
  let r ← IO.mkRef "first"
  r.set "second"
  let old ← r.swap "third"
  r.modify (· ++ "!")
  IO.println s!"refs: {old} {← r.get}"
  let viaST := runST fun σ => do
    let r ← ST.mkRef (σ := σ) (α := Nat) 3
    let other ← ST.mkRef (σ := σ) (α := Nat) 4
    let eq ← r.ptrEq other
    r.modify (· + 6)
    let old ← r.swap 2
    return (eq, old, ← r.get)
  IO.println s!"st: {viaST}"

private def files : IO Unit := do
  let d : System.FilePath := "work"
  IO.FS.createDir d
  IO.FS.createDir (d / "sub")
  let path := d / "out.txt"
  IO.FS.writeFile path "one\ntwo\nthree\n"
  let h ← IO.FS.Handle.mk path .append
  h.putStr "four\n"
  h.flush
  let h ← IO.FS.Handle.mk path .readWrite
  IO.println s!"lines: {← IO.FS.lines path}"
  IO.println s!"line: {(← h.getLine).trimAsciiEnd}"
  h.rewind
  h.putStr "ONE"
  h.rewind
  discard h.getLine
  h.truncate
  h.flush
  IO.println s!"truncated: {repr (← IO.FS.readFile path)}"
  let binary := d / "binary"
  IO.FS.writeBinFile binary (ByteArray.mk #[0, 1, 2, 255])
  IO.println s!"binary: {(← IO.FS.readBinFile binary).toList}"
  let metadata ← binary.metadata
  let symlink ← ("initial-link" : System.FilePath).symlinkMetadata
  IO.println s!"metadata: {metadata.byteSize} {repr metadata.type} {metadata.numLinks} {decide (metadata.modified.sec > 0)} {repr symlink.type}"
  IO.println s!"exists: {← binary.pathExists} {← binary.isDir} {← d.isDir} {← (d / "none").pathExists}"
  IO.println s!"entries: {((← d.readDir).map (·.fileName)).qsort (· < ·)}"
  let moved := d / "moved"
  IO.FS.rename binary moved
  IO.FS.hardLink moved binary
  IO.println s!"links: {(← moved.metadata).numLinks}"
  IO.FS.removeFile binary
  IO.setAccessRights moved { user := { read := true, write := true } }
  let first ← IO.FS.Handle.mk moved .read
  let second ← IO.FS.Handle.mk moved .read
  first.lock
  let blocked ← second.tryLock
  first.unlock
  let unlocked ← second.tryLock false
  second.unlock
  IO.println s!"locks: {blocked} {unlocked}"
  IO.println s!"realpath: {(← IO.FS.realPath (d / "sub")).toString.endsWith "/work/sub"}"
  IO.FS.removeDir (d / "sub")
  let (temp, path) ← IO.FS.createTempFile
  temp.putStr "temporary"
  temp.rewind
  IO.println s!"temp file: {← temp.readToEnd}"
  IO.FS.removeFile path
  let path ← IO.FS.createTempDir
  IO.println s!"temp dir: {← path.isDir}"
  IO.FS.removeDir path

private def fileErrors : IO Unit := do
  showError "missing file" (IO.FS.Handle.mk "missing.txt" .read)
  showError "permission denied" (IO.FS.Handle.mk "protected.txt" .read)
  showError "directory open" (IO.FS.Handle.mk "existing-dir" .write)
  let dir ← IO.FS.Handle.mk "existing-dir" .read
  showError "directory read" (dir.read 1)
  showError "already exists" (IO.FS.Handle.mk "initial.txt" .writeNew)
  showError "nonempty directory" (IO.FS.removeDir "existing-dir")
  showError "missing metadata" (("missing.txt" : System.FilePath).metadata)
  showError "missing realpath" (IO.FS.realPath "missing.txt")
  showError "bad rename" (IO.FS.rename "missing.txt" "new.txt")
  showError "not a directory" (("initial.txt" : System.FilePath).readDir)
  showError "embedded NUL" (IO.FS.Handle.mk "nul\x00name" .read)
  let input ← IO.getStdin
  showError "stdin write" (input.putStr "no")

private def environment : IO Unit := do
  IO.println s!"env: {← IO.getEnv "LEANFRAN_GO_IO_VALUE"} {← IO.getEnv "LEANFRAN_GO_IO_UNSET"}"
  let cwd ← IO.currentDir
  IO.println s!"cwd: {cwd == (← IO.Process.getCurrentDir)}"
  IO.Process.setCurrentDir "existing-dir"
  IO.println s!"changed: {(← IO.currentDir).fileName}"
  IO.Process.setCurrentDir cwd
  IO.println s!"app: {(← IO.appPath).isAbsolute}"
  IO.println s!"ids: {decide ((← IO.Process.getPID) > 0)} {decide ((← IO.getTID) > 0)}"
  let ms ← IO.monoMsNow
  let ns ← IO.monoNanosNow
  IO.println s!"clocks: {ms > 0 && ms ≤ (← IO.monoMsNow)} {ns > 0 && ns ≤ (← IO.monoNanosNow)}"
  let now ← Std.Time.Timestamp.now
  IO.println s!"wall clock: {decide (now.val.second.val > 0)} {0 ≤ now.val.nano.val && now.val.nano.val < 1000000000}"
  IO.println s!"random bytes: {(← IO.getRandomBytes 0).size} {(← IO.getRandomBytes 37).size}"
  IO.println s!"platform: {System.Platform.numBits} {System.Platform.isLinux} {System.Platform.isOSX} {System.Platform.isWindows} {System.Platform.isEmscripten}"
  IO.println s!"hardware concurrency: {decide (System.Platform.Internal.getHardwareConcurrency () > 0)}"

private def processes : IO Unit := do
  let out ← IO.Process.output { cmd := "sh", args := #["-c", "printf out; printf err >&2; exit 3"] }
  IO.println s!"output: {out.exitCode} {out.stdout} {out.stderr}"
  let out ← IO.Process.run { cmd := "cat" } (input? := some "cat input")
  IO.println s!"input: {out}"
  let env := #[("LEANFRAN_GO_IO_VALUE", none), ("LEANFRAN_GO_IO_CHILD", some "child-only")]
  let args := #["-c", "printf '%s:%s:%s' \"$LEANFRAN_GO_IO_CHILD\" \"$LEANFRAN_GO_IO_VALUE\" \"${PWD##*/}\""]
  let out ← IO.Process.run { cmd := "sh", args, env, cwd := some "existing-dir" }
  IO.println s!"child env and cwd: {out}"
  let pathEnv := #[("PATH", some "."), ("LEANFRAN_GO_IO_CHILD", some "path-only")]
  let out ← IO.Process.run { cmd := "look-up", cwd := some "existing-dir", env := pathEnv, inheritEnv := false }
  IO.println s!"child path: {out}"
  let child ← IO.Process.spawn { cmd := "cat", stdin := .piped, stdout := .piped }
  let (stdin, child) ← child.takeStdin
  stdin.putStr "piped\n"
  stdin.write (ByteArray.mk #[0, 1, 255])
  stdin.flush
  let line ← child.stdout.getLine
  let bytes ← child.stdout.read 3
  let eof ← child.stdout.read 1
  IO.println s!"spawn: {repr line} {bytes.toList} {eof.isEmpty} {← child.wait}"
  let missing ← IO.Process.output { cmd := "leanfran-go-io-no-such-command" }
  IO.println s!"missing: {missing.exitCode} {repr missing.stderr}"
  let dir ← IO.Process.output { cmd := "sh", cwd := some "missing-dir" }
  IO.println s!"bad cwd: {dir.exitCode} {repr dir.stderr}"
  let sleeper ← IO.Process.spawn { cmd := "sleep", args := #["30"] }
  IO.println s!"tryWait: {decide (sleeper.pid > 0)} {← sleeper.tryWait}"
  sleeper.kill
  IO.println s!"kill: {← sleeper.wait}"

private def largeProcess : IO Unit := do
  let script := "head -c 1048576 /dev/zero | tr '\\000' E >&2; head -c 1048576 /dev/zero | tr '\\000' O"
  let out ← IO.Process.output { cmd := "sh", args := #["-c", script] }
  let stdout := out.stdout.toUTF8
  let stderr := out.stderr.toUTF8
  if out.exitCode != 0 || stdout.size != 1048576 || stderr.size != 1048576 then
    throw (IO.userError "large process returned a truncated stream")
  IO.println s!"large process: {out.exitCode} {stdout.size} {stderr.size} {hash stdout} {hash stderr}"

private def tasks : IO Unit := do
  let pureTask := Task.pure (3 : Nat)
  let spawned := Task.spawn fun _ => pureTask.get + 5
  let mapped := spawned.map (· * 2)
  let bound := mapped.bind fun n => Task.spawn fun _ => n + 10
  let first ← IO.wait bound
  let act ← IO.asTask (pure (first + 1))
  let more ← BaseIO.mapTask (fun x => pure (x.toOption.getD 0 * 2)) act
  let last ← BaseIO.bindTask more fun n => pure (Task.pure (n + 1))
  IO.cancel last
  IO.println s!"tasks: {first} {act.get.toOption} {← IO.wait last} {← IO.waitAny [Task.pure first]} {← IO.checkCanceled} {← IO.hasFinished last}"
  let p ← IO.Promise.new (α := Nat)
  let result := p.result?
  IO.println s!"pending: {repr (← IO.getTaskState result)}"
  IO.println s!"wait any: {← IO.waitAny [result, Task.pure (some 11)]}"
  p.resolve 42
  p.resolve 99
  IO.println s!"promise: {← IO.wait result} {← IO.hasFinished result} {p.result!.get}"
  let dropped ← do
    let p ← IO.Promise.new (α := Nat)
    pure p.result?
  IO.println s!"dropped promise: {← IO.wait dropped}"

@[noinline] private def arrays (n : UInt8) : IO Unit := do
  let src := "abé🙂Z".toUTF8
  let dest : ByteArray := (ByteArray.mk #[0, n, 255]).push 7
  let withCopy := src.copySlice 2 dest 1 6
  let append := src.copySlice 2 dest 20 30 false
  let replaced := dest.set! 0 n
  IO.println s!"bytes: {dest.toList} {withCopy.toList} {dest[2]!} {append.toList} {replaced.toList}"
  IO.println s!"text: {String.fromUTF8? (withCopy.extract 1 7)} {String.fromUTF8? dest} {hash src} {hash "abé🙂Z"}"
  let a := (FloatArray.mk #[1.25, 2.5]).push 3.5
  let b := a.set! 1 4.25
  IO.println s!"floats: {a.size} {a[1]!} {b[1]!} {b[2]!}"
  IO.println s!"misc: {Array.replicate 3 n} {(["a", "b", "c"].toArray.extract 1 9)} {Nat.lcm 18 (n.toNat + 6)} {mixHash n.toUInt64 22}"

def run (args : List String) : IO UInt32 := do
  match args with
  | ["streams"] => streams
  | ["files"] => files
  | ["file-errors"] => fileErrors
  | ["environment"] => environment
  | ["processes"] => processes
  | ["large-process"] => largeProcess
  | ["tasks"] => tasks
  | ["pending-promise"] =>
    let promise ← IO.Promise.new (α := Nat)
    let result ← IO.wait promise.result?
    promise.resolve 1
    IO.println result
  | ["arrays"] => arrays 42
  | ["uncaught"] => discard (IO.FS.Handle.mk "missing.txt" .read)
  | ["exit"] => IO.Process.exit 7
  | ["force-exit"] => IO.Process.forceExit 8
  | _ => throw (IO.userError "unknown IO fixture")
  return 0

end LeanGoTest.Io
