include generated\ bindings/leanfran.mk

.PHONY: check
check:
	$(CC) -std=c11 -Wall -Wextra -Werror $(LEANFRAN_CFLAGS) src/main.c $(LEANFRAN_LDLIBS) -o consumer
	./consumer
