.PHONY: test-kernel test-value-cost test-value-regions

GO_SOURCES += testdata/kernel
CHECK_TARGETS += test-kernel test-value-cost test-value-regions

test-kernel:
	bash ../../maint/Go/test-kernel.sh

test-value-cost: test-kernel
	go test -count=1 -v -run 'TestScopedCommandAllocations|TestCommandAllocations|TestLastRowCommandAllocations|TestWalkAllocations|TestLeakedValues' ./test-out/_generated/kernel

test-value-regions: test-kernel
	go test -count=1 -v -run TestRegionThroughput ./test-out/_generated/kernel
