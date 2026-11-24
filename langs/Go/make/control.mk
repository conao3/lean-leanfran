.PHONY: test-depth test-complexity test-ir-coverage test-race

GO_SOURCES += testdata/control
CHECK_TARGETS += test-depth test-complexity test-ir-coverage test-race

test-depth:
	bash ../../maint/Go/test-depth.sh

test-complexity:
	bash ../../maint/Go/test-complexity.sh

test-ir-coverage:
	bash ../../maint/Go/test-ir-coverage.sh

test-race:
	bash ../../maint/Go/test-race.sh
