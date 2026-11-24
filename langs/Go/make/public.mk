.PHONY: test-public

GO_SOURCES += testdata/public
CHECK_TARGETS += test-public

test-public:
	bash ../../maint/Go/test-public.sh
