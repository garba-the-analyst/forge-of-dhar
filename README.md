# ⚒️ The Forge of Dhar (V0 Architecture)

**The Forge of Dhar** is the foundational, pre-bootstrapped systems compiler for the **Dhar Programming Language**. 

Written entirely in 100% bare-metal x86_64 NASM Assembly by Garba the Analyst, V0 operates with **zero external dependencies** (no libc, no standard library). It is a self-contained systems compiler capable of dynamic Lexical Analysis, Indentation-Based Syntax Parsing, Symbol Table resolution, and Assembly Code Generation.

This V0 architecture serves as the Turing-complete foundation required to compile Dhar Stage 1 (the self-hosted compiler).

---

## ⚡ Core Architecture & Philosophy

Dhar is a native systems language designed for high performance, explicit memory control, and direct Linux kernel interaction.

*   **No Garbage Collector:** Dhar handles memory natively.
*   **Invisible RAII Scope Tracking:** The compiler tracks scope via Python-style indentation. When an array or buffer goes out of scope, the compiler mathematically injects `sys_munmap` instructions to deallocate memory automatically at compile-time. *(Note: Deallocation is intentionally neutered in V0 to protect static `.bss` allocations).*
*   **Direct Kernel Access:** The `sys` keyword allows developers to invoke Linux syscalls natively.
*   **Flat Stack Control Flow:** Uses a Control Flow (CF) Stack to manage nested `when` (if), `fallback` (else), `span` (while), and `task` (function) blocks.

---

## 🛠️ Prerequisites & Building

To build the V0 compiler, you must be on a Linux x86_64 system (or WSL) with `nasm` and `ld` installed.

### 1. Compile the Dhar Compiler (`dharc`)
```bash
nasm -f elf64 -g -F dwarf src/lexer.asm -o build/lexer.o
ld -m elf_x86_64 -o build/dharc build/lexer.o
```

### 2. Compile a Dhar Source File
```bash
# Translates Dhar source code into x86_64 Assembly
./build/dharc tests/reference.dhar
```

### 3. Assemble and Run the Output
```bash
nasm -f elf64 build/output.asm
ld -m elf_x86_64 -o build/output build/output.o
./build/output
```

---

## 📖 Dhar Syntax Reference (V0)

Dhar replaces ambiguous programming terminology with strict, industrial-grade keywords.

### 1. Tasks (Functions)
The fundamental unit of execution. Every Dhar program must contain a `task core():` entry point.
```dhar
task greet():
    lock msg: str = "Hello from Dhar!\n"
    sys 1, 1, msg, 17

task core():
    greet()
```

### 2. Variables & Memory
Memory mutability must be explicitly declared.
*   `lock`: Immutable memory (constant).
*   `flux`: Mutable, fluid memory (variable).
*   **Types:** `i32` (Integer), `str` (String Pointer), `raw` (Static Byte Array).

```dhar
flux state: i32 = 1
flux buffer: raw[1024]
buffer[0] = state
```

### 3. Control Flow
Dhar uses `when` (if), `fallback` (else), and `span` (while).
```dhar
flux iter: i32 = 1
span iter == 1:
    lock loop_msg: str = "Loop executed!\n"
    sys 1, 1, loop_msg, 15
    iter = iter + 1
```

### 4. Native Syscalls
Interact with the kernel directly using `sys [rax], [rdi], [rsi], [rdx]`.
```dhar
lock out: str = "System writing directly to stdout.\n"
sys 1, 1, out, 35
```

---

## 🚀 The Roadmap
*   [x] **Stage 0 (The Forge):** Bare-metal x86_64 Assembly compiler (Current).
*   [ ] **Stage 1 (Self-Hosting):** Rewriting the compiler entirely in `dharc.dhar`.
*   [ ] **Stage 2 (Cross-Platform):** Expanding the Code Generator to support Windows (PE/COFF) and macOS (Mach-O) native binaries.