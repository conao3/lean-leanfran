CHECK_TARGETS += test-complexity test-depth

.PHONY: test-complexity test-depth

check: $(CHECK_TARGETS)

test-complexity: vendor/autoload.php
	bash ../../maint/PHP/test-complexity.sh

test-depth: vendor/autoload.php
	bash ../../maint/PHP/test-depth.sh
