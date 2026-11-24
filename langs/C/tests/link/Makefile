.DEFAULT_GOAL := check
.PHONY: check

include $(BINDINGS)

check:
	$(CC) -std=c11 $(PUBLIC_API_CFLAGS) main.c $(PUBLIC_API_LDLIBS) -o "$(OUTPUT)"
	"$(OUTPUT)"
