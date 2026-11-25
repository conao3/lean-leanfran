.PHONY: test-kernel test-value-cost test-value-regions test-value-misuse test-array-cost

GO_SOURCES += testdata/kernel
CHECK_TARGETS += test-kernel test-value-cost test-value-regions test-value-misuse test-array-cost

test-kernel:
	bash ../../maint/Go/test-kernel.sh

test-value-cost: test-kernel
	go test -count=1 -v -run 'TestScopedCommandAllocations|TestCommandAllocations|TestLastRowCommandAllocations|TestWalkAllocations|TestLeakedValues' ./test-out/_generated/kernel

test-value-regions: test-kernel
	go test -count=1 -v -run TestRegionThroughput ./test-out/_generated/kernel

test-value-misuse: test-kernel
	CGO_ENABLED=1 go test -race -count=1 -v -run 'TestTakeUnaffiliatedFromTwoRegions|TestUnscopedZeroInputCallInRegion|TestRegionLeakedValues' ./test-out/_generated/kernel

test-array-cost: test-kernel
	LEANFRAN_ARRAY_COST=1 go test -count=1 -v -run 'TestArrayCallCost|TestRuntimeWrappersInline' ./test-out/_generated/kernel
