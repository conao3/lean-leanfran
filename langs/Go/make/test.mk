.PHONY: test test-diff test-runtime test-determinism

CHECK_TARGETS += test

test: test-runtime test-diff test-determinism

test-runtime:
	go vet ./...
	go vet ../../maint/Go/gen-externs/main.go
	go vet ../../maint/Go/fuzz-gen/main.go
	go vet ../../maint/Go/numeric/main.go
	golangci-lint run ../../maint/Go/gen-externs/main.go
	golangci-lint run ../../maint/Go/fuzz-gen/main.go
	golangci-lint run ../../maint/Go/numeric/main.go
	golangci-lint run
	CGO_ENABLED=0 go test ./...

test-diff:
	bash ../../maint/Go/test-diff.sh

test-determinism:
	bash ../../maint/Go/test-determinism.sh
