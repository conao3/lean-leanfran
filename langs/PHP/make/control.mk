CHECK_TARGETS += test-complexity

.PHONY: test-complexity

check: $(CHECK_TARGETS)

test-complexity: vendor/autoload.php
	bash ../../maint/PHP/test-complexity.sh
