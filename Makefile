# Dhar Multi-Target Makefile
ASM = nasm
LD_LINUX = ld
LD_WINDOWS = x86_64-w64-mingw32-ld

SRC_DIR = src
BUILD_DIR = build
BENCH_DIR = benchmarks/workloads

.PHONY: all clean linux windows

all: linux

linux: 
	@echo "[+] Compiling Dhar native Linux target..."
	mkdir -p $(BUILD_DIR)
	$(ASM) -f elf64 $(SRC_DIR)/lexer.asm -o $(BUILD_DIR)/dharc.o
	$(LD_LINUX) -m elf_x86_64 -o $(BUILD_DIR)/dharc $(BUILD_DIR)/dharc.o

windows:
	@echo "[+] Cross-compiling Dhar Windows PE target..."
	mkdir -p $(BUILD_DIR)
	$(ASM) -f win64 $(SRC_DIR)/lexer.asm -o $(BUILD_DIR)/dharc_win.o
	$(LD_WINDOWS) -mi386pep -o $(BUILD_DIR)/dharc.exe $(BUILD_DIR)/dharc_win.o -lkernel32 -luser32

clean:
	rm -rf $(BUILD_DIR)/*
