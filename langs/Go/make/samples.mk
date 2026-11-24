.PHONY: samples

CHECK_TARGETS += samples

samples:
	bash ../../maint/Go/test-samples.sh
