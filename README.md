# ⚒️ The Forge of Dhar (V0.1 Architecture)

**The Forge of Dhar** is the foundational, pre-bootstrapped systems compiler for the **Dhar Programming Language**. 

Designed and engineered by **Garba the Analyst**, V0 operates with **zero external dependencies** (no libc, no standard library). Written entirely in 100% bare-metal x86_64 NASM Assembly, it is a self-contained systems compiler capable of dynamic Lexical Analysis, Indentation-Based Syntax Parsing, Symbol Table resolution, and direct Assembly Code Generation.

This repository serves as the Turing-complete foundation required to compile Dhar Stage 1 (the self-hosted compiler).

---

## ⚡ Core Philosophy & Memory Architecture

Dhar is a native systems language built for absolute determinism, explicit memory sovereignty, and direct Linux kernel interaction.

*   **No Garbage Collector:** Dhar handles memory natively without the latency of a runtime garbage collector.
*   **Invisible RAII Scope Tracking:** The compiler maps memory scope via strict Python-style indentation. When an array or buffer goes out of scope, the CF (Control Flow) Stack mathematically injects `sys_munmap` instructions to deallocate memory automatically. *(Note: Deallocation is intentionally neutered in V0 to protect static `.bss` bootstrap allocations).*
*   **Direct Kernel Sovereignty:** The `sys` keyword allows developers to invoke Linux syscalls natively, acting as a direct bridge to the CPU ring 0.
*   **Flat Stack Control Flow:** Uses a centralized Control Flow Stack to securely manage nested conditionals, loops, and function closures without recursive overhead.

---

## 📖 Language Reference & Syntax

Dhar replaces ambiguous programming terminology with strict, industrial-grade keywords and strict typing rules.

### 1. Variables & Memory Mutability
Memory state and mutability must be explicitly declared upon initialization using type annotations.

*   `lock`: **Immutable memory (Constant).** The value is permanently bound to the address and cannot be reassigned.
*   `flux`: **Mutable memory (Variable).** The value stored at the address can be modified dynamically during execution.

```dhar
lock pi: i32 = 3
flux counter: i32 = 0
counter = counter + 1
```

### 2. Data Types
V0 implements strict, systems-level types mapped directly to x86_64 registers and `.bss` data segments.

| Type | Description | Internal Representation | Example Initialization |
| :--- | :--- | :--- | :--- |
| `i32` | 32-bit Integer | Stored in 64-bit `resq` registers for V0 compatibility. | `flux age: i32 = 24` |
| `str` | String Pointer | Emits native C-style null-terminated strings to the `.data` segment. | `lock greeting: str = "Hello World\n"` |
| `raw[N]` | Static Byte Array | Allocates `N` contiguous bytes of uninitialized raw memory in `.bss`. | `flux buffer: raw[1024]` |

### 3. Array Indexing & Memory Operations
Dhar provides direct manipulation of contiguous memory arrays.

**Writing to Memory Arrays:**
```dhar
flux buffer: raw[1024]
flux index: i32 = 0
flux val: i32 = 255

buffer[index] = val
```

**Reading from Raw Memory (V0.1 `peek`):**
Because Dhar operates close to the hardware, reading specific bytes from raw memory buffers requires the explicit `peek` instruction.
```dhar
flux target_byte: i32
flux read_index: i32 = 0

; Syntax: peek [destination], [raw_array], [index]
peek target_byte, buffer, read_index
```

### 4. Control Flow
Dhar discards ambiguous constructs like traditional `if/else` and `while` keywords in favor of strict execution routing blocks:

*   `when`: Evaluates a logical condition. Executes the indented block if true; otherwise, branches to `fallback`.
*   `fallback`: The safety net executed if a preceding `when` conditional check fails.
*   `span`: Creates a cyclical execution loop that evaluates and iterates as long as the condition remains true.

```dhar
flux state: i32 = 1

when state == 1:
    lock msg: str = "State is nominal.\n"
    sys 1, 1, msg, 18
fallback:
    lock err: str = "State degraded.\n"
    sys 1, 1, err, 16

span state == 1:
    state = state + 1
```

### 5. Native Syscalls & Kernel Interaction
Interact directly with the Linux Kernel using the `sys` keyword. Arguments map sequentially to x86 registers: `sys [rax], [rdi], [rsi], [rdx]`.

**Executing a Syscall:**
```dhar
; sys_write (rax=1) to stdout (rdi=1)
lock out: str = "Writing to terminal directly.\n"
sys 1, 1, out, 31
```

**Capturing Kernel Responses (V0.1 `sysret`):**
To capture the result left by the kernel in the `rax` register following a syscall, immediately invoke `sysret`.
```dhar
; sys_open a file (rax=2)
flux file_path: str = "config.dhar"
sys 2, file_path, 0, 0

; Capture the File Descriptor assigned by the kernel
flux file_descriptor: i32
sysret file_descriptor
```

### 6. Tasks (Functions)
The fundamental unit of execution modularity. Every executable must contain a `task core():` entry point. Functions are invoked natively using standard identifier-parentheses syntax.

```dhar
task initialize_subsystem():
    lock init_msg: str = "Subsystem online.\n"
    sys 1, 1, init_msg, 19

task core():
    initialize_subsystem()
```

---

## 🛠️ Building & Usage

To build the V0 compiler, you must be on a Linux x86_64 environment with `nasm` and `ld` installed.

### 1. Build the Dhar Compiler (`dharc`)
```bash
nasm -f elf64 -g -F dwarf src/lexer.asm -o build/lexer.o
ld -m elf_x86_64 -o build/dharc build/lexer.o
```

### 2. Compile Dhar Source Code
```bash
# Translates Dhar code into raw x86_64 Assembly (build/output.asm)
./build/dharc source_file.dhar
```

### 3. Assemble and Link the Output Binary
```bash
nasm -f elf64 build/output.asm
ld -m elf_x86_64 -o build/output build/output.o
./build/output
```