.DEFAULT_GOAL := check
.PHONY: build check check-models check-model check-translate check-fuzz check-verify check-integration check-random check-samples format format-check

c_sources := $(wildcard support/*.c support/*.h tests/*.c tests/link/*.c tests/types/*.c \
	tests/embed/app/src/*.c tests/embed/app/src/*.h tests/embed/app/src/nested/*.h \
	tests/verify/*.c tests/verify/translation/*.c tests/verify/translation/*.h \
	tests/verify/states/src/*.c tests/verify/random/src/*.c tests/verify/trust/src/*.c \
	tests/verify/records/*.c tests/verify/records/src/*.c tests/verify/records/src/*.h tests/verify/files/src/*.c \
	samples/pricing/*.c samples/verified-clamp/src/*.c)
clang_format := clang-format --style='{BasedOnStyle: LLVM, IndentWidth: 4}'
VERIFY_TARGET ?= check-verify

build:
	lake build

check: check-models $(VERIFY_TARGET) check-integration

check-models: build format-check check-model check-translate check-fuzz

check-integration: build check-random check-samples
	../../maint/C/test-diff.sh
	../../maint/C/test-link.sh
	../../maint/C/test-embed.sh
	../../maint/C/test-schema.sh

check-model: build
	../../maint/C/test-model.sh

check-translate: build
	../../maint/C/test-translate.sh

check-fuzz: build
	../../maint/C/test-fuzz.sh

check-verify: build
	../../maint/C/test-verify.sh

check-random: build
	../../maint/C/test-random.sh

check-samples: build
	../../maint/C/test-samples.sh

format:
	$(clang_format) -i $(c_sources)

format-check:
	$(clang_format) --dry-run --Werror $(c_sources)
