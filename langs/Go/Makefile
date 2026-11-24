.DEFAULT_GOAL := check
.PHONY: build check format format-check gen-externs externs-check

GO_SOURCES := leanfran.go rt ../../maint/Go/gen-externs
CHECK_TARGETS :=

include make/*.mk

build:
	lake build leanfran-go

check: format-check externs-check $(CHECK_TARGETS)

format:
	gofumpt -w $(GO_SOURCES)

format-check:
	go version
	@files="$$(gofumpt -l $(GO_SOURCES))" || exit $$?; \
	if [ -n "$$files" ]; then printf '%s\n' "$$files"; exit 1; fi

.PHONY: generate-externs-inventory
gen-externs externs-check: generate-externs-inventory

generate-externs-inventory:
	mkdir -p test-out
	go run ../../maint/Go/gen-externs/main.go rt > test-out/RuntimeExterns.lean

gen-externs:
	cp test-out/RuntimeExterns.lean LeanGo/RuntimeExterns.lean

externs-check:
	diff -u LeanGo/RuntimeExterns.lean test-out/RuntimeExterns.lean
