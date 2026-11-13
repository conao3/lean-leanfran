import LeanPythonTest.Json

def main : IO Unit := for l in LeanPythonTest.Json.lines do IO.println l
