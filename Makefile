BACKENDS ?= Rust Python TypeScript Clojure

.DEFAULT_GOAL := check
.PHONY: build check format format-check

build check format format-check:
	@set -eu; for backend in $(BACKENDS); do \
		case "$$backend" in Rust|Python|TypeScript|Clojure) ;; *) echo "Unknown backend: $$backend" >&2; exit 2 ;; esac; \
		nix develop ".#$$(echo "$$backend" | tr A-Z a-z)" -c $(MAKE) -C "langs/$$backend" $@; \
	done
