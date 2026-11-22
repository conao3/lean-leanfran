CHECK_TARGETS += test-io

.PHONY: test-io
test-io: vendor/autoload.php
	bash ../../maint/PHP/test-io.sh
