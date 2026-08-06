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
	$(ASM) -f elf64 $(BUILD_DIR)/output.asm -o $(BUILD_DIR)/output.o
	$(LD_LINUX) -m elf_x86_64 -o $(BUILD_DIR)/dhar_linux $(BUILD_DIR)/output.o

windows:
	@echo "[+] Cross-compiling Dhar Windows PE target..."
	mkdir -p $(BUILD_DIR)
	$(ASM) -f win64 $(BUILD_DIR)/output_win.asm -o $(BUILD_DIR)/output_win.obj
	$(LD_WINDOWS) -mi386pep -o $(BUILD_DIR)/dhar.exe $(BUILD_DIR)/output_win.obj -lkernel32 -luser32

clean:
	rm -rf $(BUILD_DIR)/*
