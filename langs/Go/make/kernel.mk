.PHONY: test-kernel

GO_SOURCES += testdata/kernel
CHECK_TARGETS += test-kernel

test-kernel:
	bash ../../maint/Go/test-kernel.sh
