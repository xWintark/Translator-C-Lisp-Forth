CC     = gcc
BISON  = bison
CFLAGS = -Wall -Wextra -Wno-unused-function

TARGETS = trad back

.PHONY: all clean

all: $(TARGETS)

# Stage 1: C-like syntax -> Common Lisp
trad: trad.y
	$(BISON) -d $< -o trad.tab.c
	$(CC) $(CFLAGS) trad.tab.c -o $@

# Stage 2: Common Lisp -> Forth
back: back.y
	$(BISON) -d $< -o back.tab.c
	$(CC) $(CFLAGS) back.tab.c -o $@

clean:
	rm -f *.tab.c *.tab.h trad back trad.exe back.exe
