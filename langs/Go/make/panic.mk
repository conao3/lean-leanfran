.PHONY: test-panic

GO_SOURCES += testdata/panic
CHECK_TARGETS += test-panic

test-panic:
	bash ../../maint/Go/test-panic.sh
