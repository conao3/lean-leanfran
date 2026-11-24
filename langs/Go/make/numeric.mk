.PHONY: test-numeric

CHECK_TARGETS += test-numeric

test-numeric:
	bash ../../maint/Go/test-numeric.sh
