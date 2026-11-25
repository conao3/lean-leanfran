.DEFAULT_GOAL := check
.PHONY: build check format format-check

c_sources := $(wildcard support/*.c support/*.h tests/*.c tests/link/*.c tests/types/*.c tests/embed/app/src/*.c tests/embed/app/src/*.h tests/embed/app/src/nested/*.h)
clang_format := clang-format --style='{BasedOnStyle: LLVM, IndentWidth: 4}'

build:
	lake build

check: build format-check
	../../maint/C/test-diff.sh
	../../maint/C/test-link.sh
	../../maint/C/test-embed.sh
	../../maint/C/test-schema.sh

format:
	$(clang_format) -i $(c_sources)

format-check:
	$(clang_format) --dry-run --Werror $(c_sources)

c_sources += $(wildcard tests/verify/*.c)

.PHONY: check-model
check: check-model

check-model: build
	../../maint/C/test-model.sh

c_sources += $(wildcard tests/verify/translation/*.c tests/verify/translation/*.h)

.PHONY: check-translate
check: check-translate

check-translate: build
	../../maint/C/test-translate.sh
