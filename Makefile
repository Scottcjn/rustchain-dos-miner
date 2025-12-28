# RustChain DOS Miner Makefile
# For DJGPP cross-compilation

CC = i586-pc-msdosdjgpp-gcc
CFLAGS = -O2 -Wall
LIBS = -lwatt

all: miner.exe entropy.exe

miner.exe: rustchain_dos_miner.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

entropy.exe: entropy_dos.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f *.exe *.o

.PHONY: all clean
