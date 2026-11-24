BACKENDS ?= Rust Python TypeScript Clojure PHP Go

.DEFAULT_GOAL := check
.PHONY: build check format format-check

build check format format-check:
	@set -eu; for backend in $(BACKENDS); do \
		case "$$backend" in Rust|Python|TypeScript|Clojure|PHP|Go) ;; *) echo "Unknown backend: $$backend" >&2; exit 2 ;; esac; \
		shells=$$(printf '%s' "$$backend" | tr '[:upper:]' '[:lower:]'); \
		if [ "$$backend:$@" = PHP:check ]; then shells="php php85"; fi; \
		if [ "$$backend:$@" = Go:check ]; then shells="go go126"; fi; \
		status=0; \
		for shell in $$shells; do \
			nix develop ".#$$shell" -c $(MAKE) -C "langs/$$backend" $@ || status=$$?; \
		done; \
		if [ "$$status" -ne 0 ]; then exit "$$status"; fi; \
	done
