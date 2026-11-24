.DEFAULT_GOAL := check
.PHONY: build check format format-check

c_sources := $(wildcard support/*.c support/*.h support/*.inc tests/*.c tests/types/*.c)
clang_format := clang-format --style='{BasedOnStyle: LLVM, IndentWidth: 4}'

build:
	lake build

check: build format-check
	../../maint/C/test-diff.sh

format:
	$(clang_format) -i $(c_sources)

format-check:
	$(clang_format) --dry-run --Werror $(c_sources)
