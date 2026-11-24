.PHONY: samples

GO_SOURCES += samples/value-server/main.go
CHECK_TARGETS += samples

samples:
	bash ../../maint/Go/test-samples.sh
