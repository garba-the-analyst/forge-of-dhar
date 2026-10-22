# Dhar Multi-Target Makefile
ASM = nasm
LD_LINUX = ld

SRC_DIR = src/asm
BUILD_DIR = build
BENCH_DIR = benchmarks/workloads

ASM_MODULES = entry.asm data.asm runtime.asm tokenize.asm parse.asm \
              calls.asm symbols.asm frames.asm codegen.asm

.PHONY: all clean linux windows-exe test status site

all: linux

linux:
	@echo "[+] Compiling Dhar native Linux target (StageAlpha 3 modules)..."
	mkdir -p $(BUILD_DIR)
	$(ASM) -f elf64 -I src/asm src/asm/entry.asm -o $(BUILD_DIR)/dharc.o
	$(LD_LINUX) -m elf_x86_64 -o $(BUILD_DIR)/dharc $(BUILD_DIR)/dharc.o

# Compile a Dhar program for Windows x64 (needs lld-link and llvm-dlltool; on Windows use link.exe
# with the same flags). Usage:  make windows-exe SRC=prog.dhar  ->  build/prog.exe
# Note: dharc itself is a Linux program; it *emits* Windows code. The flags below give the image a
# fixed low base because Stage 0 uses absolute 32-bit addresses (see docs).
SRC ?= benchmarks/workloads/test.dhar
windows-exe: linux
	mkdir -p $(BUILD_DIR)
	llvm-dlltool -m i386:x86-64 -d tests/kernel32.def -l $(BUILD_DIR)/kernel32.lib
	./$(BUILD_DIR)/dharc $(SRC) --target=windows
	$(ASM) -f win64 $(BUILD_DIR)/output.asm -o $(BUILD_DIR)/prog.obj
	lld-link /subsystem:console /entry:main /base:0x400000 /fixed /largeaddressaware:no /nodefaultlib \
	    /out:$(BUILD_DIR)/prog.exe $(BUILD_DIR)/prog.obj $(BUILD_DIR)/kernel32.lib

# Conformance battery on both targets (Windows is run in the CPU emulator, tools/pe_emulate.py).
test: linux
	./tests/conformance_alpha.sh
	TARGET=windows ./tests/conformance_alpha.sh

# Regenerate every generated status block (website board, README, progress log) from status/status.json.
status:
	python3 status/render.py

# Rebuild the `website` branch that GitHub Pages serves (add PUSH=1 to push it).
site:
	python3 status/render.py
	./tools/publish_site.sh $(if $(PUSH),--push,)

clean:
	rm -rf $(BUILD_DIR)/*
