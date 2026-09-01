# **⚒️ The Forge of Dhar (V0.4.0-doc Architecture)**

**The Forge of Dhar** is the foundational, pre-bootstrapped systems compiler for the **Dhar Programming Language**.  
Designed and engineered by **Garba the Analyst**, V0 operates with **zero external dependencies** (no libc, no standard library, no runtime). Written entirely in 100% bare-metal x86\_64 NASM Assembly (src/lexer.asm), it is a self-contained systems compiler capable of dynamic Lexical Analysis, Indentation-Based Syntax Parsing, Symbol Table resolution, Six-Operator Conditionals, `mold`/`forge` (`{}`), `shift`/`scan`/`cycle`, `view`/`grab` borrowing, `pull`/`expose` modules, `state`/`trap`/`enforce` error model, and direct native kernel syscall dispatch on the fully operational Linux x86\_64 target (Windows/WASI scaffolding active; see Target Matrix).  
This repository serves as the Turing-complete foundation required to compile Dhar Stage 1 (the self-hosted compiler written in Dhar itself).

## **📋 Table of Contents**

> 1. [Core Philosophy & Memory Architecture]
> 2. [Compiler Internal Memory Layout] 
> 3. [Exhaustive Language Reference & Grammar]
   * [Keywords & Reserved Words]
   * [Variables, Scope & Mutability] 
   * [Data Types & Memory Layout]
   * [Variable Declaration & Reassignment Semantics]
   * [Array Indexing & Memory Operations]
   * [Control Flow Constructs]
   * [Kernel Interfacing & System Calls]
   * [Tasks (Functions) & Subroutine Semantics]
   * [Molds & Forges (Data Layout vs Logic)]
   * [Borrowing: view/grab]
   * [Modules: pull/expose]
   * [Error Model: state/trap/enforce]
> 4. [Target Architecture & Cross-Compilation Matrix]
> 5. [Building & Compiler CLI Usage]
> 6. [Benchmark Suite & Telemetry Analysis]
> 7. [Comprehensive Code Examples]

## **⚡ Core Philosophy & Memory Architecture**

Dhar is a native systems language built for absolute determinism, explicit memory sovereignty, and bare-metal performance.

> * **Zero Abstraction Tax:** Dhar compiles directly into native target assembly without linking against standard C libraries (-nostdlib), runtime managers, or garbage collectors.  
> * **Deterministic Indentation Scoping:** Memory scope is tracked via strict indentation level counting. Local variables and array buffers are bound to their indentation block.  
> * **Scope Cleanup Tracking:** The compiler tracks scope boundaries via an internal Control Flow (CF) Stack. When an indented block exits, the compiler emits cleanup routines to deallocate local buffers automatically.  
> * **Direct Kernel Sovereignty:** System operations bypass user-space wrappers. The sys keyword maps directly to kernel instruction interfaces (syscall on Linux x86\_64, svc \#0 on ARM64, WinAPI imports on Windows, and wasi\_snapshot\_preview1 on WebAssembly).  
> * **Flat Stack Control Flow:** Manages nested conditionals, loops, and function closures via an internal static Control Flow Stack without recursive call overhead during compilation.

## **🧠 Compiler Internal Memory Layout**

The Stage 0 assembly engine (src/lexer.asm) manages its state within a pre-allocated 1MB dynamic memory architecture inside the .bss segment:

| Segment Memory Array | Reserved Size | Capacity / Purpose |
| :---- | :---- | :---- |
| token\_array | 1 MB (1,048,576 bytes) | Holds up to **65,536 tokens** (16 bytes per token struct tracking type, value pointer, indent level, and line number). |
| string\_pool | 1 MB (1,048,576 bytes) | Contiguous ASCII pool storing string literals and identifier names during lexing. |
| symbol\_table | 1 MB (1,048,576 bytes) | Holds up to **32,768 symbols** (32 bytes per entry tracking identifier, type tag, mutability, scope depth, and array dimension). |
| cf\_stack | 64 KB (65,536 bytes) | Centralized Control Flow stack tracking nested block IDs, scope depths, and branching labels. |
| file\_buffer | 1 MB (1,048,576 bytes) | Holds raw input .dhar source code loaded directly via sys\_open and sys\_read. |
| word\_buffer | 4 KB (4,096 bytes) | Transient character accumulator used during token scanning. |

## **📖 Exhaustive Language Reference & Grammar**

### **1\. Keywords & Reserved Words**

Dhar replaces ambiguous programming keywords with explicit, systems-level keywords:

| Keyword | Category | Usage & Description |
| :---- | :---- | :---- |
| lock | Declaration | Immutable variable (Constant). Permanently binds a memory address to an initial value. |
| flux | Declaration | Mutable variable. Memory contents at this symbol's address can be modified dynamically. |
| task | Structure | Declares an executable procedure or function unit. |
| i32 | Type | Signed 32-bit integer scalar type. |
| str | Type | Immutable null-terminated ASCII string pointer. |
| raw\[N\] | Type | Static byte buffer array allocating N contiguous bytes of memory. |
| when | Control Flow | Conditional branching check (equivalent to if). Executes indented block if condition evaluates to true. |
| fallback | Control Flow | Alternate execution branch (equivalent to else) triggered if preceding when check fails. |
| span | Control Flow | Deterministic loop block (equivalent to while). Iterates as long as condition evaluates to true. |
| sys | System | Invokes native kernel system call or API operation directly. |
| sysret | System | Captures the immediate kernel return status register (rax) following a sys call. |
| peek | Memory | Low-level memory instruction to read a single byte from a raw memory buffer into a variable. |

### **2\. Variables, Scope & Mutability**

Memory mutability in Dhar must be explicitly declared upon initialization.

#### **Mutability Qualifiers**

> * lock: **Immutable Constant.** Reassigning a lock symbol after initialization triggers a compile-time error: Semantic Error: Cannot reassign immutable 'lock' variable.  
> * flux: **Mutable Variable.** Allows variable contents to be updated during runtime execution.

#### **Scoping & Indentation Rules**

Dhar uses **indentation-based block scoping** (4 spaces or 1 tab per level):

> 1. Variables declared within an indented block are bound to that indentation level.  
> 2. When the compiler exits an indented block, symbols declared within that block become unreachable.  
> 3. Attempting to re-declare an active symbol within the same or parent scope triggers: Semantic Error: Identifier already declared.

### **3\. Data Types & Memory Layout**

Dhar V0.4.0-doc provides full primitive types: `i8,i16,i32,i64` `u8,u16,u32,u64` `f32,f64` `char` `str` `bool` `raw`, each mapped to specific x86\_64 memory segments and register behaviors:

#### **A. i32 (32-bit Integer)**

> * **Description:** Signed integer type.  
> * **Internal Representation:** Stored as 64-bit quadwords (resq 1\) in the .bss segment in V0 to maintain 64-bit alignment across x86\_64 registers (rax, rcx, rdi).  
> * **Storage Location:** Uninitialized inside .bss; values initialized inline generate mov qword \[symbol\], value instructions inside .text.  
> * **Example Declarations:**  
>   Code snippet  
>   lock max\_count: i32 \= 100  
>   flux current\_count: i32 \= 0

#### **B. str (Null-Terminated String Pointer)**

> * **Description:** Points to an immutable ASCII sequence in memory.  
> * **Internal Representation:** Emitted as native null-terminated (and optional newline-terminated) byte arrays inside the .data segment using standard labels (str\_0 db "...", 0).  
> * **Pointer Mechanism:** Variable symbols point directly to the base address of the emitted string literal.  
> * **Example Declarations:**  
>   Code snippet  
>   lock banner: str \= "System Initialized\\n"  
>   flux dynamic\_msg: str

#### **C. raw\[N\] (Static Raw Byte Buffer)**

> * **Description:** Allocates N contiguous uninitialized bytes of memory for direct buffer manipulation, file I/O operations, and array processing.  
> * **Internal Representation:** Emitted in the .bss section as resq ceil(N/8) or exact byte reservations.  
> * **Index Offset:** Indexed starting from byte position 0 to N-1.  
> * **Example Declarations:**  
>   Code snippet  
>   flux read\_buffer: raw\[1024\]  
>   flux frame\_data: raw\[4096\]

### **4\. Variable Declaration & Reassignment Semantics**

Dhar requires explicit type annotations using the colon : syntax.

#### **Initialized Variable Declaration**
```
Code snippet  
lock status\_code: i32 \= 200  
flux loop\_counter: i32 \= 0  
lock greeting: str \= "Welcome to Dhar\\n"
```
#### **Uninitialized Variable Declaration**

Uninitialized variables allocate space in the .bss segment without generating immediate inline assignment instructions.
```
Code snippet  
flux total\_bytes: i32  
flux input\_buffer: raw\[2048\]
```
#### **Scalar Reassignment & Arithmetic Semantics**

Mutable flux variables can be reassigned using literals, other variables, or binary arithmetic operations (+, \-):
```
Code snippet  
flux val\_a: i32 \= 10  
flux val\_b: i32 \= 5

; Direct assignment  
val\_a \= 20

; Variable-to-variable assignment  
val\_a \= val\_b

; Arithmetic reassignment (Addition and Subtraction)  
val\_a \= val\_a \+ 1  
val\_a \= val\_a \- val\_b  
val\_a \= val\_b \+ 42
```
### **5\. Array Indexing & Memory Operations**

Dhar provides raw memory manipulation over raw\[N\] arrays using direct indexing and low-level byte peeking.

#### **A. Writing to Memory Arrays**

Elements inside a raw buffer are updated using bracket notation buffer\[index\] \= value.
```
Code snippet  
task test\_memory():  
    flux buffer: raw\[1024\]  
    flux index: i32 \= 0  
    lock val: i32 \= 65

    ; Write value 65 ('A') to position index 0  
    buffer\[index\] \= val

    ; Write using integer literal index  
    buffer\[1```\] \= 66
```
> * **Under the Hood Assembly Generation:**  
>   Writing to an array loads the index into rax, the value into rcx, and executes an indexed memory store:  
>   Code snippet  
>   mov rax, qword \[index\]  
>   mov rcx, qword \[val\]  
>   mov qword \[buffer \+ rax\*8\], rcx

#### **B. Reading from Raw Memory (peek)**

Reading specific bytes from contiguous memory buffers into scalar variables is performed using the peek keyword.  
**Syntax:** peek \[destination\_variable\], \[source\_buffer\], \[index\_offset\]
```
Code snippet  
task read\_memory():  
    flux memory\_pool: raw\[512\]  
    flux captured\_byte: i32  
    flux offset: i32 \= 0

    ; Reads 1 byte from memory\_pool at offset index into captured\_byte  
    peek captured\_byte, memory\_pool, offset
```
> * **Under the Hood Assembly Generation:**  
>   Code snippet  
>   mov rax, qword \[offset\]  
>   mov rsi, memory\_pool  
>   xor rcx, rcx  
>   mov cl, byte \[rsi \+ rax\]  
>   mov qword \[captured\_byte\], rcx

### **6\. Control Flow Constructs**

Dhar replaces standard if/else and while keywords with deterministic execution routing blocks.

#### **A. when and fallback Conditional Blocks**

> * when: Evaluates a comparison check. Supported operators: \== (equal), \!= (not equal), \< (less than), \> (greater than), \<= (less or equal), \>= (greater or equal). If true, execution continues into the indented block. If false, it jumps directly to .L\_FALLBACK\_ or .L\_END\_.  
> * fallback: Executes if the preceding when check fails.
```
Code snippet  
flux system\_state: i32 \= 1

when system\_state \== 1:  
    lock ok\_msg: str \= "System state nominal.\\n"  
    sys 1, 1, ok\_msg, 22  
fallback:  
    lock err\_msg: str \= "System error detected.\\n"  
    sys 1, 1, err\_msg, 23
```
Conditions compare an identifier against either an integer literal or another variable of the same type. Arithmetic expressions inside conditions (e.g., x + 1 \< 5) are not supported in V0; compute into a variable first.

#### **B. span Loop Blocks**

> * span: Creates an iterative loop. Evaluates the condition before each loop pass using any supported comparison operator (==, !=, <, >, <=, >=). If true, executes the indented block and jumps back to .L\_START\_.
```
Code snippet  
flux iter: i32 \= 0

span iter \< 3:  
    lock loop\_msg: str \= "Executing loop pass...\\n"  
    sys 1, 1, loop\_msg, 23  
    iter \= iter \+ 1
```
### **7\. Kernel Interfacing & System Calls**

Dhar interacts directly with the host kernel via the sys keyword, mapping sequentially to host registers.

#### **System Call Syntax**

sys \[sys\_number\], \[arg1\], \[arg2\], \[arg3\]

#### **x86\_64 Register Mapping**

| Parameter | Description | Target x86\_64 Register |
| :---- | :---- | :---- |
| sys\_number | Syscall ID (e.g., 1 \= Write, 2 \= Open, 60 \= Exit) | rax |
| arg1 | First Argument (e.g., File Descriptor 1 for stdout) | rdi |
| arg2 | Second Argument (e.g., Buffer or String Address) | rsi |
| arg3 | Third Argument (e.g., Byte Count / Buffer Length) | rdx |

#### **Standard Output Example (sys\_write)**
```
Code snippet  
; sys\_write(fd=1, buf="Hello\\n", len=6)  
lock msg: str \= "Hello\\n"  
sys 1, 1, msg, 6
```
#### **File Input/Output & Capturing Kernel Return Values (sysret)**

System calls that return data (such as sys\_open returning a file descriptor in rax) use the sysret keyword immediately following the sys statement.  
**Syntax:** sysret \[destination\_variable\]
```
Code snippet  
task read\_file\_example():  
    lock file\_path: str \= "config.txt"  
    flux fd: i32  
    flux buffer: raw\[1024\]  
    flux bytes\_read: i32

    ; sys\_open (rax=2), path="config.txt", flags=0 (O\_RDONLY), mode=0  
    sys 2, file\_path, 0, 0  
    sysret fd

    ; sys\_read (rax=0), fd, buffer, count=1024  
    sys 0, fd, buffer, 1024  
    sysret bytes\_read

    ; sys\_close (rax=3), fd  
    sys 3, fd, 0, 0
```
### **8\. Tasks (Functions) & Subroutine Semantics**

A task represents a discrete execution unit.

#### **Rules for Tasks**

> 1. Every Dhar program must contain a main entry point defined as task core():.  
> 2. Tasks are invoked by name followed by parentheses: task\_name().  
> 3. Task boundaries generate native assembly subroutines (call task\_name and ret).
```
Code snippet  
task print\_header():  
    lock header: str \= "--- DHAR SYSTEM ENGINE \---\\n"  
    sys 1, 1, header, 27

task execute\_diagnostics():  
    lock diag: str \= "Running diagnostics...\\n"  
    sys 1, 1, diag, 23

task core():  
    print\_header()  
    execute\_diagnostics()
```
## **🎯 Target Architecture & Cross-Compilation Matrix**

The Dhar compiler includes target triple dispatch logic (src/lexer.asm), enabling code generation routing across multiple target platforms:

| Target Platform Flag | Binary Object Format | Entry Point | Calling Convention / System Bridge | Target Status in V0 |
| :---- | :---- | :---- | :---- | :---- |
| \--target=linux | ELF64 (-f elf64) | \_start | Native x86\_64 Kernel syscall | **Fully Operational (Stage 0 Native)** |
| \--target=windows | PE32+ (-f win64) | main | WinAPI (WriteFile, ExitProcess, GetStdHandle) | **Code Generator Scaffolding Active** |
| \--target=wasi | WebAssembly Bytecode | \_start | WASI Preview 1 Imports (fd\_write, proc\_exit) | **Code Generator Scaffolding Active** |

## **🛠️ Building & Compiler CLI Usage**

### **Prerequisites**

> * Linux OS (x86\_64 architecture)  
> * nasm (Netwide Assembler)  
> * ld (GNU Linker)  
> * hyperfine *(Optional, for running benchmark suites)*

### **Step 1: Assemble the Stage 0 Native Compiler (dharc)**

Compile the raw assembly compiler engine. Note: the production compiler is **src/lexer.asm alone**; the Python files under src/ are an archived pre-bootstrapping prototype and play no role in the toolchain.
```
Bash  
mkdir \-p build  
nasm \-f elf64 \-g \-F dwarf src/lexer.asm \-o build/lexer.o  
ld \-m elf\_x86\_64 \-o build/dharc build/lexer.o
```
### **Step 2: Compile a Dhar Source File**

Pass your .dhar source file through dharc to generate native assembly:
```
Bash  
\# Compile for Native Linux ELF Target (Default)  
./build/dharc benchmarks/workloads/test.dhar \--target=linux

\# Cross-Compile for Windows PE Target  
./build/dharc benchmarks/workloads/test.dhar \--target=windows
```
### **Step 3: Assemble and Link the Emitted Binary**
```
Bash  
\# Assemble emitted Linux assembly  
nasm \-f elf64 build/output.asm \-o build/output.o

\# Link into native executable  
ld \-m elf\_x86\_64 \-o build/test\_program build/output.o

\# Execute  
./build/test\_program
```
## **📊 Benchmark Suite & Telemetry Analysis**

Dhar was benchmarked against leading system languages, JIT runtimes, and interpreted engines using a standardized high-throughput byte-stream iteration simulator (1,048,576 total condition evaluations: 16 outer cycles x 65,536 inner iterations each).  
Benchmarks were executed under strict CPU core pinning (taskset \-c 1\) with 100 statistical runs per language via hyperfine (3-run warmup). Full methodology and raw telemetry live in [benchmarks/README.md](benchmarks/README.md).

### **Performance Leaderboard (V0.3.0 Telemetry)**

| Rank | Language / Runtime Compiler | Mean | Median | Standard Deviation (σ) | Index vs C |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **1** | C (GCC \-nostdlib \-O3) | **1.58 ms** | 0.47 ms | ±2.91 ms | 1.0x (Baseline) |
| **2** | C++ (G++ \-O3) | **2.32 ms** | 0.90 ms | ±5.21 ms | ~1.5x slower |
| **3** | Rust (rustc Release \-C opt-level=3) | **2.61 ms** | 2.06 ms | ±1.78 ms | ~1.7x slower |
| **4** | **Dhar V0 (Native x86\_64 Assembly Engine)** | **8.40 ms** | **7.28 ms** | $\\pm 4.93\\text{ ms}$ | \~5.3x slower |
| **5** | Node.js (V8 JIT JavaScript) | **98.5 ms** | 85.1 ms | ±55.7 ms | \~62x slower |
| **6** | PHP 8.3 (CLI) | **110.6 ms** | 92.5 ms | ±75.9 ms | \~70x slower |
| **7** | Java (OpenJDK 21 JIT) | **165.1 ms** | 122.2 ms | ±142.1 ms | \~104x slower |
| **8** | Python 3.12 | **180.6 ms** | 148.1 ms | ±92.2 ms | \~114x slower |

### **Architectural Conclusion**

Dhar V0 is the fastest entry among non-optimizing compilers and sits squarely in the native tier: roughly **5x behind auto-vectorized \-O3 C**, and an order of magnitude ahead of every JIT or interpreted engine (V8, JVM, PHP, CPython).

This gap is expected and documented for V0:

> * **Zero Optimization Passes:** The Stage 0 engine emits naive scalar code. Every variable lives in a memory-resident .bss slot — there is no register allocation, no instruction scheduling, no strength reduction, and no SIMD auto-vectorization. GCC vectorizes this particular workload heavily; Dhar executes it one comparison per instruction.
> * **Honest Measurement Floor:** At single-digit-millisecond scale, process startup and scheduler jitter dominate the statistics (note σ ≈ mean across the compiled tier; medians are the more stable indicator). Fine-grained rankings inside the native tier should be read as directional.
> * **Correctness Before Speed:** V0.3.0 fixed inverted codegen for relational operators in span/when conditions (see changelog in benchmarks/README.md). Pre-V0.3.0 telemetry measured a workload whose loops silently never executed and has been fully retired.

By compiling directly to lean x86\_64 machine code with zero runtime, standard library, or GC overhead — while still executing real branchy workloads at native-tier speeds out of the box — Dhar provides the deterministic foundation Stage 1 self-hosting requires. Register allocation and peephole optimization are scheduled as post-bootstrap compiler passes.


## **💻 Comprehensive Code Examples**

### **Example 1: Foolproof System Verification (tests/foolproof.dhar)**

Demonstrates memory allocations, array index stores, control flow branching (when/fallback), loops (span), and system output:

```
Code snippet  
task test\_memory():  
    flux buffer: raw\[1024\]  
    flux index: i32 \= 0  
    lock val: i32 \= 42

    buffer\[index\] \= val

    lock mem\_msg: str \= "\[OK\] Memory allocation and array indexing passed.\\n"  
    sys 1, 1, mem\_msg, 50

task test\_logic():  
    flux state: i32 \= 1  
    flux out\_msg: str

    when state \== 1:  
        out\_msg \= "\[OK\] Control flow (when) passed.\\n"  
        state \= state \+ 1  
    fallback:  
        out\_msg \= "\[FAIL\] Control flow (fallback) broke.\\n"

    sys 1, 1, out\_msg, 33

    when state \== 2:  
        flux loop\_count: i32 \= 0  
        span loop\_count \== 0:  
            lock loop\_msg: str \= "\[OK\] Loop (span) and Math passed.\\n"  
            sys 1, 1, loop\_msg, 34  
            loop\_count \= loop\_count \+ 1  
    fallback:  
        lock fail\_msg: str \= "\[FAIL\] Math state failed.\\n"  
        sys 1, 1, fail\_msg, 26

task core():  
    lock start\_msg: str \= "--- DHAR V0 FOOLPROOF TEST INITIATED \---\\n"  
    sys 1, 1, start\_msg, 41

    test\_memory()  
    test\_logic()

    lock end\_msg: str \= "--- ALL V0 SYSTEMS OPERATIONAL \---\\n"  
    sys 1, 1, end\_msg, 35
```
### **Example 2: Interactive State Machine & Looping (tests/showcase.dhar)**

```
Code snippet  
task greet():  
    lock msg: str \= "Hello from Dhar\!\\n"  
    sys 1, 1, msg, 17

task calculate():  
    flux state: i32 \= 1  
    flux result: str

    when state \== 1:  
        result \= "Math logic check: PASS\\n"  
        flux temp\_buffer: raw\[1024\]  
        state \= state \+ 1  
    fallback:  
        result \= "Math logic check: FAIL\\n"  
        flux error\_buffer: raw\[2048\]

    sys 1, 1, result, 23

task loop\_test():  
    flux iter: i32 \= 1

    span iter \== 1:  
        lock loop\_msg: str \= "Loop executed\!\\n"  
        sys 1, 1, loop\_msg, 15  
        iter \= iter \+ 1

task core():  
    greet()  
    calculate()  
    loop\_test()

    lock exit\_msg: str \= "Done.\\n"  
    sys 1, 1, exit\_msg, 6
```

## **🏛️ Author & Licensing**

> * **Designer & Engineer:** Abdullahi Baba Garba (Garba the Analyst)  
> * **License:** Open-Source Systems Project under the MIT License.