.PHONY: test-verify test-verify-samples

GO_SOURCES += lean/assets.go leanfrantest testdata/verify/states/states.go testdata/verify/translation testdata/verify/model/model_test.go samples/verified-clamp/clamp.go samples/verified-nibble/nibble.go
CHECK_TARGETS += test-verify

test-verify: build
	bash ../../maint/Go/test-verify.sh

samples: test-verify-samples

test-verify-samples: build
	bash ../../maint/Go/test-verify-samples.sh
