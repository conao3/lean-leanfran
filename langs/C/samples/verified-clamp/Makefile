include leanfran/leanfran.mk

.PHONY: run
run:
	$(CC) -std=c11 -Wall -Wextra -Werror $(LEANFRAN_CFLAGS) src/main.c src/clamp.c $(LEANFRAN_LDLIBS) -o clamp-demo
	./clamp-demo
