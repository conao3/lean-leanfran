.PHONY: test test-diff test-runtime

CHECK_TARGETS += test

test: test-runtime test-diff

test-runtime:
	go vet ./...
	go vet ../../maint/Go/gen-externs/main.go
	golangci-lint run
	CGO_ENABLED=0 go test ./...

test-diff:
	bash ../../maint/Go/test-diff.sh
