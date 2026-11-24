namespace Checks

private def unfinished (_ : UInt32) : UInt32 := by sorry

def dependsOnSorry (n : UInt32) : UInt32 := n + unfinished n

@[extern "leanfran_test_increment"]
private opaque externalIncrement : UInt32 → UInt32

private def implementation (n : UInt32) : UInt32 := externalIncrement n

@[implemented_by implementation]
def alternative (n : UInt32) : UInt32 := n + 1

def withExtern (n : UInt32) : UInt32 := alternative n

end Checks
