CONTROL_CHECK_TARGETS := test-complexity test-depth test-ir-coverage fuzz

CHECK_TARGETS += $(CONTROL_CHECK_TARGETS)

.PHONY: $(CONTROL_CHECK_TARGETS)

check: $(CONTROL_CHECK_TARGETS)

test-complexity: vendor/autoload.php
	bash ../../maint/PHP/test-complexity.sh

test-depth: vendor/autoload.php
	bash ../../maint/PHP/test-depth.sh

test-ir-coverage:
	bash ../../maint/PHP/test-ir-coverage.sh

fuzz: vendor/autoload.php
	bash ../../maint/PHP/fuzz.sh
