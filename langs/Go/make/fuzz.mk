.PHONY: fuzz

SEED ?= 1
N ?= 2000
CHECK_TARGETS += fuzz

fuzz:
	bash ../../maint/Go/fuzz.sh "$(SEED)" "$(N)"
