.PHONY: test-embed-scan test-embed test-embed-samples

GO_SOURCES += embed.go cmd internal testdata/embed/types testdata/embed/consumer testdata/embed/oracle samples/embed-range/main.go samples/embed-range/pricing/pricing.go samples/embed-models/main.go samples/embed-models/orders/orders.go samples/embed-models/receipts/receipts.go
CHECK_TARGETS += test-embed-scan test-embed

test-embed-scan:
	go test ./internal/embed

test-embed: build
	bash ../../maint/Go/test-embed.sh

samples: test-embed-samples

test-embed-samples: build
	bash ../../maint/Go/test-embed-samples.sh
