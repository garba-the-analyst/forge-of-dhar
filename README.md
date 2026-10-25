# **⚒️ The Forge of Dhar (V0.4.0-doc Architecture)**

**The Forge of Dhar** is the foundational, pre-bootstrapped systems compiler for the **Dhar Programming Language**.  
Designed and engineered by **Garba the Analyst**, V0 operates with **zero external dependencies** (no libc, no standard library, no runtime). Written entirely in 100% bare-metal x86\_64 NASM Assembly (src/asm/, nine one-definition-per-file modules per StageAlpha §3), it is a self-contained systems compiler for the **Strict Alpha §2.2 subset only**: `lock/flux`, `task/give`, `when/shift/fallback` (six operators), `span/cycle/scan/escape/skip`, `mold` layout-only, `pull`/`expose` directives, `bool` literals (`true`/`false` as numeric 1/0), array indexing over `i32/str/bool/raw[N]`, `peek/poke`, `sys/sysret` (+ value form), and `gen`. `forge`/`view`/`grab`/`state`/`trap`/`enforce` are **not in subset and are rejected** with `StageAlpha 2.2` diagnostics; modeled bodies are rejected as not-subset (field defaults/generics/nesting). It emits programs for Linux x86\_64 and Windows x64 (Windows is verified in a CPU emulator, not yet on a real machine); any other `--target` is refused with an error. `give` returns a value or one operation (`give a + b`).  
This repository is the Stage 0 bridge: its job is to compile Stage 1, the Dhar compiler written in Dhar itself ([honing-dhar](https://github.com/garba-the-analyst/honing-dhar)). Stage 1 does not compile yet; the status table below says what does.

## **🔎 Current status**

<!-- gen:status:start -->
| Area | Status | What it means today |
| --- | --- | --- |
| Stage 0 compiler | **Works** | `dharc` is written in NASM x86-64 assembly (nine modules, no libc). It reads a `.dhar` file and writes assembly; `nasm` and a linker turn that into a program. The conformance battery has 108 tests and all of them pass on both targets. |
| Native programs, no runtime | **Works** | Output is a small static program that talks to the operating system directly: `gen` and `sys` both end in a system call, with no library between. The examples below are about 9 KB each. |
| Bounds checking on buffers | **Works** | An index outside a `raw[N]` buffer stops the program with `Dhar: index out of bounds` and exit status 1, instead of silently corrupting memory. |
| The language itself | **Partly** | A strict first subset: `i32`, `str`, `bool` and `raw[N]`; type inference from the first value (`lock x = 5`); tasks with parameters; `give` with a value or one operation (`give a + b`); `gen(...)` to print a string, a number or an `i32`, `str` or `bool` variable; `when`/`shift`/`fallback`; loops; `sys` calls; layout-only `mold`. Anything outside the subset is rejected with a clear message. Known limit: a global variable cannot have an initial value yet (assign it inside a task); the compiler says so instead of silently ignoring it. |
| Target: Linux x86-64 | **Works** | Programs are built, linked and run natively in the tests. |
| Target: Windows x64 | **Partly** | Programs assemble as win64, link into a PE, and run correctly in a CPU emulator that checks the Windows calling rules; all 108 tests pass there. It has not been run on a real Windows machine yet, and `dharc` itself still runs only on Linux (on Windows, use WSL). |
| Targets: ARM64, RISC-V, WebAssembly (WASI) | **Not yet** | `dharc` refuses these with an error rather than producing the wrong output. The author decided on 23 October 2026 to build them in Stage 0 itself (not postpone them to Stage 1); nothing of that is built yet, and each target is switched on only when the whole test battery passes on it. The Canon still says Stage 0 targets x86-64 only, so the decision needs Canon amendment A-2. |
| Stage 1: the compiler written in Dhar | **Designed** | 8 source files exist in the Honing Dhar repository (lexer, parser, AST, symbols, type check, IR, code generation, driver) and all of them pass through Stage 0. They are scaffolding and stubs, not a working compiler. |
| Safety without a garbage collector | **Designed** | Compile-time ownership and borrowing (`view`, `grab`) and the error model (`state`, `trap`, `enforce`) are specified. Stage 0 rejects them; there is no borrow checker yet. |
| Cybersecurity, AI and quantum direction | **Designed** | The direction and its acceptance gates are written down as Canon Amendment A-1, a draft that still needs the author's ratification. Nothing for them is built yet: no `std.crypto`, no float or tensor types, no quantum back end. |
| Self-hosting | **Not yet** | Stage 1 does not compile itself, so the byte-for-byte bootstrap check has not been run. |
| Optimiser | **Not yet** | Every variable lives in memory and nothing is kept in registers. That is the main reason Dhar trails C in the speed test. Register allocation is planned for after the bootstrap. |
| Modules, standard library, `Kun` | **Not yet** | `pull` and `expose` are validated but link a single file. There is no importer, no standard library and no package manager yet; programs call the system directly. |
| Try Dhar in the browser | **Not yet** | Planned for this website. It needs a way to run `dharc` and the result in the browser, and nothing of that exists yet. |

Status checked 25 October 2026 against commit `b4bfb21`. Words: **Works** = runs and is tested; **Partly** = some of it runs and is tested; **Designed** = specified or scaffolded, not working; **Not yet** = nothing exists. Generated from `status/status.json` (see HONESTY.md in the Dhar-website-and-docs repository).
<!-- gen:status:end -->

The website, the Canon of Dhar, the progress reports and the survey are in [Dhar-website-and-docs](https://github.com/garba-the-analyst/Dhar-website-and-docs) (live at https://dhar.onrender.com). The full dated log is in [PROGRESS.md](PROGRESS.md). The direction (security first, then AI, then quantum) is in [Canon Amendment A-1](https://github.com/garba-the-analyst/Dhar-website-and-docs/blob/main/docs/canon/AMENDMENT-A1-DIRECTION.md). How these numbers are kept honest is in [HONESTY.md](https://github.com/garba-the-analyst/Dhar-website-and-docs/blob/main/docs/HONESTY.md).

## **📋 Table of Contents**

> 0. [Current status](#-current-status)
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
> * **Direct Kernel Sovereignty:** System operations bypass user-space wrappers. The sys keyword maps directly to kernel instruction interfaces (`syscall` on Linux x86\_64; on Windows, a small built-in stub turns the same call into the matching Win32 call. `svc #0` for ARM64 and the WASI imports are planned for the Stage 1 back ends, not built).  
> * **Flat Stack Control Flow:** Manages nested conditionals, loops, and function closures via an internal static Control Flow Stack without recursive call overhead during compilation.

## **🧠 Compiler Internal Memory Layout**

The Stage 0 assembly engine (src/asm/) manages its state within a pre-allocated 1MB dynamic memory architecture inside the .bss segment:

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

Dhar Stage 0 implements the Strict Alpha §2.2 types only: `i32`, `str`, `bool`, `raw[N]` (byte array, see §5). All other Spec1 types (`i8,i16,i64` `u8,u16,u32,u64` `f32,f64` `char`, `state`, generics, `option`, collections) are lexed as keywords so they **reject loudly** (`subset`/`todo` diagnostics) instead of vanishing as identifiers. Storage is 64-bit-aligned quadwords for scalars; `raw[N]` reserves `ceil(N/8)` quadwords in `.bss`/frames but addresses **bytes** (`N` bytes, index `0..N-1`).

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

Elements inside a raw buffer are updated using bracket notation buffer\[index\] \= value. Since `raw\[N\]` is N bytes with no element type (Spec1 §14.4), a store writes a single byte at `buffer + index` — the same width `peek`/`poke` use, so stores and peeks always agree.
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
>   Writing to an array loads the index into rax, the value into rcx, and executes an indexed byte store:  
>   Code snippet  
>   mov rax, qword \[index\]  
>   mov rcx, qword \[val\]  
>   mov byte \[buffer \+ rax\], cl

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

#### **C. Bounds Checking (Spec1 §14.4)**

Every indexing operation — `buffer\[index\] \= value`, `peek`, `poke` — is bounds-checked against the declared `raw\[N\]` size. An out-of-range (or negative) index traps: the program writes `Dhar: index out of bounds` to stderr and exits 1. It never silently touches adjacent memory and never segfaults. Task-local `raw\[N\]` arrays reserve their full `ceil(N/8)` frame slots, so in-range indices always land inside the frame.

### **6\. Control Flow Constructs**

Dhar replaces standard if/else and while keywords with deterministic execution routing blocks.

#### **A. when and fallback Conditional Blocks**

> * when: Evaluates a comparison check. Supported operators: \== (equal), \!= (not equal), \< (less than), \> (greater than), \<= (less or equal), \>= (greater or equal). If true, execution continues into the indented block. If false, it jumps directly to .L\_FALLBACK\_ or .L\_END\_.  
> * shift: Else-if link (Spec1 §8.1, may repeat). Evaluated only if all previous links failed; exactly one branch of the chain runs. A `shift` without a matching `when`/`shift` at the same indent is a compile-time error, as is a second `fallback:`.  
> * fallback: Executes if the preceding when check fails.
```
task core():
    flux system_state: i32 = 2
    when system_state == 1:
        gen("System state nominal.\n")
    shift system_state == 2:
        gen("System state degraded.\n")
    fallback:
        gen("System error detected.\n")
```
Conditions compare an identifier against either an integer literal or another variable of the same type. Arithmetic expressions inside conditions (e.g., x + 1 \< 5) are not supported in V0; compute into a variable first. A trailing `:` is required after every `when`/`shift` condition.

#### **B. span Loop Blocks**

> * span: Creates an iterative loop. Evaluates the condition before each loop pass using any supported comparison operator (==, !=, <, >, <=, >=). If true, executes the indented block and jumps back to .L\_START\_.
```
task core():
    flux iter: i32 = 0
    span iter < 3:
        gen("Executing loop pass...\n")
        iter = iter + 1
```

#### **C. cycle Infinite Loops with escape**

> * cycle: Infinite loop with no condition (Spec1 §8.2). Exits only via `escape`, which jumps to the end of the nearest enclosing loop. A `cycle:` with an empty body is a compile-time error (it could never terminate).
```
Code snippet  
flux iter: i32 \= 0

cycle:  
    iter \= iter \+ 1  
    when iter \== 5:  
        escape
```

#### **D. scan Value Loops**

> * scan x in buf:: Iterates over each byte of a `raw` buffer, declaring `x` (a fresh `flux i32` in the current scope) bound to each value in order. The buffer must be declared `raw`; bounds come from its declared size. `in` is contextual (compared by content, never reserved).
```
Code snippet  
flux lb: raw\[4\]  
flux total: i32 \= 0

scan byte\_val in lb:  
    total \= total \+ byte\_val
```

#### **E. escape and skip**

> * escape: Breaks out of the nearest enclosing loop (`span`, `cycle`, or `scan`), continuing after it.  
> * skip: Skips to the next iteration of the nearest enclosing loop (re-checks the condition for `span`/`scan`).  
> * Both are compile-time errors outside a loop body. See `tests/loops.dhar` (cycle \= 5, span-skip sum \= 12, scan sum \= 5).
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

#### **Printing: gen**

`gen(...)` is the print function. It takes exactly one argument, in parentheses: a string, a number, or the name of an `i32`, `str` or `bool` variable or parameter. The type of a name is whatever it was declared as, or, if it was declared without a type, the type of its first value.
```
task core():
    lock count = 7          ; no type written: the number makes it an i32
    lock name = "Dhar"      ; a string makes it a str
    flux ready = true       ; true and false make it a bool
    gen("Hello from ")
    gen(name)
    gen("\n")
    gen(count)
    gen("\n")
    gen(ready)
    gen("\n")
```
This prints `Hello from Dhar`, `7` and `true`, each on its own line. `gen` writes exactly what it is given: a string is written as it is (no newline is added), a number in decimal, a bool as `true` or `false`. It is rejected, with its own message, if the parentheses are missing, if there is more than one argument or anything after the closing parenthesis, or if the name is an array or a task. `gen` writes to standard output only; for any other file descriptor, or to read, use `sys`.

#### **Standard Output with sys (the low-level route)**

`gen` is built on the system call below; use `sys` directly when you need another descriptor, a buffer you built yourself, or the return value.
```
; sys_write(fd=1, buf="Hello\n", len=6)
lock msg: str = "Hello\n"
sys 1, 1, msg, 6
```
#### **File Input/Output & Capturing Kernel Return Values (sysret)**

System calls that return data (such as sys\_open returning a file descriptor in rax) use the sysret keyword immediately following the sys statement.  
**Syntax:** sysret \[destination\_variable\]

An equivalent value form stores rax directly: `fd = sys(2, file_path, 0, 0)`.

Buffer arguments may be globals or task-local `raw\[N\]` arrays; the compiler passes the buffer address automatically in both cases (locals via `lea`).
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
task print_header():
    gen("--- DHAR SYSTEM ENGINE ---\n")

task execute_diagnostics():
    gen("Running diagnostics...\n")

task core():
    print_header()
    execute_diagnostics()
```
### **9\. Molds & Forges (layout-only, Spec1 §9)**

> * `mold Name { ... }` is implemented: the parser validates the header and every `lock`/`flux` field line (subset primitives, `raw[N]` sized; no defaults, no generics, no nested types/molds), records `(name, field-count, byte-size)` in a 64-entry type table (separate namespace; redefinition rejected), and the code generator skips the block emitting nothing. Empty molds accepted; unterminated `{` rejected at EOF. Fields create no symbols (use outside rejects as undeclared). Per-field offsets are Beta's job — the bridge records the layout summary only.
> * `forge Name { ... }` (method attach, Spec1 §10) is **not in subset** and is rejected with `StageAlpha 2.2` diagnostics. No logic is emitted for either keyword in Stage 0.

### **10\. Borrowing: view/grab (not in Stage 0)**

> * `view` (`&` read-only) and `grab` (`&mut`) are Spec1 §14 ideas for Stage 1+. In Stage 0 both are **rejected** (`StageAlpha 2.2`). There is no borrow checker, no `&` emission, and no aliasing analysis. Dead codegen stubs (`add rcx,1`) exist but are unreachable because the parser rejects first — they emit nothing.

### **11\. Modules: pull/expose/gen**

> * `gen(...)` is implemented as the print function (see "Printing: gen" above): a string or number literal, `true`/`false`, or the name of an `i32`, `str` or `bool` variable or parameter, declared with a type or inferred. It emits the write itself; a small helper is added to the output only for the kinds a program uses.
> * `pull <ident|string>` is implemented as a validated directive: the single-file bridge links exactly one file, so it binds nothing (real module resolution is Beta). `expose <ident>` additionally requires a previously declared symbol. Both emit no code. There is no importer, no registry, no `Kun` in Stage 0. Single-file programs with one `task core():` remain the supported unit.

### **12\. Error Model: state/trap/enforce (not in Stage 0)**

> * `state` is a **reserved type name** (Spec1 App. A) and is rejected as a type or identifier (`Expected Identifier after 'lock'/'flux'`). Shipped tests use `st_val` instead.
> * `trap`/`enforce` (and `attempt/rescue/ensure/raise`) are **not in subset** and are rejected (`StageAlpha 2.2`). The only Stage-0 failure path is the Spec1 §14.4 bounds trap: out-of-range/negative `raw` index writes `Dhar: index out of bounds` to stderr and exits 1. No unwinding, no typed errors.

### **13\. Output-channel width (known limitation)**


> * `raw[N]` elements are **bytes**: `buf[i] = v` stores the low byte (`mov byte [buf+rax], cl`), `peek` loads one byte zero-extended. This is self-consistent (stores and peeks agree at every index).
> * Consequence: `buf[0] = res` publishes only `res & 0xFF` (low byte). Full-range `i32` checksums (`-10` → `246`, `338` → `82`) truncate. The `dharfuzz` harness compares full 64-bit (`struct.unpack("<q")`), so full-range random programs report `wrong` even when arithmetic/control/calls are correct. Restrict published values to `0..255` for exact gate parity, or mask expected with `& 0xFF`. See `PHASE0_BASELINE.md` gate table. Multi-byte store is **not** planned in Stage 0 (would break byte-array consistency); it is Stage-1+ design work.

> * **`bool` literals:** `true`/`false` are stored as `1`/`0` (lexer rewrite, shared numeric path): `flux b: bool = true` and `when b == true` pass. The lexer remembers that the word was written, so `gen(true)` prints `true` while `gen(1)` prints `1`. The words are reserved and rejected as identifiers. Repeat the battery any time with `tests/conformance_alpha.sh` (the case count is in the status table; needs `nasm`/`ld`/`python3`. Run `TARGET=windows ./tests/conformance_alpha.sh` for the Windows target, which also needs `lld-link`, `llvm-dlltool` and `pip install unicorn pefile`; `make test` runs both).

## **🎯 Target Architecture & Cross-Compilation Matrix**

`dharc` takes `--target=linux` (the default) or `--target=windows`. Anything else, including `wasi`, `arm64` and `riscv64`, is **refused**: `dharc` prints `Fatal Error: unsupported target` on stderr, exits 1 and leaves no `output.asm` behind, so a wrong target can never silently produce Linux code.

| Target flag | Object format | Entry point | System bridge | Status |
| :---- | :---- | :---- | :---- | :---- |
| `--target=linux` | ELF64 (`nasm -f elf64`) | `_start` | `syscall` instruction | **Works.** Every conformance test runs natively. |
| `--target=windows` | PE32+ (`nasm -f win64`) | `main` | `GetStdHandle`, `WriteFile`, `ReadFile`, `ExitProcess` through a built-in `dhar_rt_syscall` stub (Linux syscall numbers 0, 1 and 60; anything else returns -38) | **Partly.** All 108 tests pass in a CPU emulator (`tools/pe_emulate.py`) that enforces the Windows x64 stack-alignment rule at every call. Not yet run on real Windows. The image is linked at a fixed low base (`/base:0x400000 /fixed /largeaddressaware:no`) because Stage 0 uses absolute 32-bit addresses. `dharc` itself runs only on Linux; on Windows use WSL. |
| `--target=arm64` | ELF64 AArch64 | | `svc #0` | **Not built.** The author decided on 23 October 2026 to build it in Stage 0; until its whole battery passes, `dharc` refuses the flag. |
| `--target=riscv64` | ELF64 RISC-V | | `ecall` | **Not built.** The author decided on 23 October 2026 to build it in Stage 0; until its whole battery passes, `dharc` refuses the flag. |
| `--target=wasi` | WebAssembly | `_start` | WASI preview 1 (`fd_write`, `proc_exit`) | **Not built.** The author decided on 23 October 2026 to build it in Stage 0; until its whole battery passes, `dharc` refuses the flag. |

The other processors are to be built in Stage 0, not postponed to Stage 1 (the author's decision of 23 October 2026). That has a cost: Stage 0 turns each token directly into assembly text with no intermediate form, so a new processor is a second code generator (the design, in the plan, is one neutral operation line per step and a small assembler-macro file per target), and it is replaced when Stage 1 gets its own back ends on the machine-independent IR. Nothing of it is built yet. Each target is switched on only when the whole conformance battery passes on it, and a target that only passes in an emulator stays **Partly**. The plan is [MULTI-ISA-PLAN.md](https://github.com/garba-the-analyst/Dhar-website-and-docs/blob/main/docs/MULTI-ISA-PLAN.md). Because the Canon's Stage-alpha document still says "x86-64 directly and only", the decision needs Canon amendment A-2; until that is ratified, the code follows the author's instruction and the Canon says otherwise.

## **🛠️ Building & Compiler CLI Usage**

### **Prerequisites**

> * Linux (x86\_64) to run `dharc`  
> * nasm (Netwide Assembler)  
> * ld (GNU Linker)  
> * hyperfine *(optional, for the benchmark suite)*  
> * `lld-link`, `llvm-dlltool`, `python3` with `unicorn` and `pefile` *(optional, only to build and test the Windows target)*

### **Step 1: Assemble the Stage 0 Native Compiler (dharc)**

Compile the raw assembly compiler engine. Note: the production compiler is **src/asm/entry.asm** (which %includes the eight sibling modules); the `python` helper files under src/ are an archived pre-bootstrapping prototype and play no role in the toolchain.
```
Bash  
mkdir \-p build  
nasm \-f elf64 \-I src/asm src/asm/entry.asm \-o build/dharc.o  
ld \-m elf\_x86\_64 \-o build/dharc build/dharc.o  
\# or simply: make
```
### **Step 2: Compile a Dhar Source File**

Pass your .dhar source file through dharc to generate native assembly:
```
Bash  
\# Compile for Native Linux ELF Target (Default)  
./build/dharc benchmarks/workloads/test.dhar \--target=linux

\# Windows x64: emits win64 assembly (build it into prog.exe with: make windows-exe SRC=prog.dhar)
./build/dharc benchmarks/workloads/test.dhar \--target=windows

\# Anything else is refused (exit 1, no output.asm): wasi, arm64, riscv64 are not built
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

### **Performance Leaderboard**

<!-- gen:speed:start -->
| Rank | Language / runtime | Median | Mean | Std dev | vs C (median) | vs C (mean) |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | C (raw, -O3) | 0.47 ms | 1.58 ms | 2.91 ms | 1.0x | 1.0x |
| 2 | C++ (-O3) | 0.90 ms | 2.32 ms | 5.21 ms | 1.9x | 1.5x |
| 3 | Rust (release) | 2.06 ms | 2.61 ms | 1.78 ms | 4.4x | 1.7x |
| 4 | **Dhar** | 7.28 ms | 8.40 ms | 4.93 ms | 15.5x | 5.3x |
| 5 | Node.js | 85.06 ms | 98.48 ms | 55.74 ms | 181.0x | 62.3x |
| 6 | PHP 8.3 | 92.49 ms | 110.57 ms | 75.86 ms | 196.8x | 70.0x |
| 7 | Java (OpenJDK) | 122.22 ms | 165.06 ms | 142.11 ms | 260.0x | 104.5x |
| 8 | Python 3 | 148.08 ms | 180.56 ms | 92.22 ms | 315.1x | 114.3x |

Dhar is **15.5x slower than C by the median** (5.3x by the mean) and **11.7x to 20.3x faster than Node.js, PHP, Java and Python by the median** (11.7x to 21.5x by the mean). Quote both columns: at a millisecond or two, process start-up and scheduler noise are as large as the work, so the mean flatters Dhar against C and the median is the steadier figure. One workload only (1,048,576 comparisons), `hyperfine` 100 runs after 3 warm-ups, pinned with `taskset -c 1`; whole-process time. Generated from `benchmarks/results/*.json`.
<!-- gen:speed:end -->

### **Architectural Conclusion**

Dhar is in the native tier but well behind optimised C: see the table above for the median and mean ratios. It is far ahead of the JIT and interpreted runtimes on this one workload. No other non-optimising compiler was measured, so no claim is made about them.

This gap is expected and documented for V0:

> * **Zero Optimization Passes:** The Stage 0 engine emits naive scalar code. Every variable lives in a memory-resident .bss slot — there is no register allocation, no instruction scheduling, and no SIMD auto-vectorization (only `inc`/`dec` folding of `x = x ± 1`). GCC vectorizes this particular workload heavily; Dhar executes it one comparison per instruction.
> * **Honest Measurement Floor:** At single-digit-millisecond scale, process startup and scheduler jitter dominate the statistics (note σ ≈ mean across the compiled tier; medians are the more stable indicator). Fine-grained rankings inside the native tier should be read as directional.
> * **Correctness Before Speed:** V0.3.0 fixed inverted codegen for relational operators in span/when conditions (see changelog in benchmarks/README.md). Pre-V0.3.0 telemetry measured a workload whose loops silently never executed and has been fully retired.
> * **Phase 1 Rebuild (correctness gate, HEAD 8326bf2):** Fixed nested-`when` fallthrough into `fallback` (both branches ran when a then-block ended in a nested `when`; `fallback` now binds only to the frame at its own indent — P7 PASS), restricted the `inc`/`dec` fold to `+`/`-` (`x = x * 1` wrongly emitted `dec`), made `buf[i] = v` a byte store per Spec1 §14.4 (`raw[N]` is N bytes; store/`peek` stride mismatch and in-range neighbor clobber fixed — P2/P11 byte-consistent), and fixed identifier initializers (`flux x: i32 = y` emitted the bare name as an immediate). Calls verified: assigned-call first-arg drop fixed (P3 `add(2,3)=5` PASS, P4 `sub3(10,3,2)=5` PASS, P9 `g(41)=42` PASS) and zero-param swallow fixed (P8 `=16` PASS), locked by `tests/calls.dhar` (4-task 0/1/2/3-arg sum `=57` PASS, shared local name `r` — FIXED 2026-10-14: owner-clobber `qword/dword` bug, see `PHASE0_BASELINE.md`). Task-local buffers passed to `sys`/`sysret` and value-form `dest = sys(...)` now pass the buffer address (P1 `=42` PASS; locals previously passed slot content, printing nothing). Global identifiers now emit as `dhar_<name>` (P12 `out=9` PASS; previously broke NASM). Every index operation is bounds-checked per Spec1 §14.4 with a stderr trap + clean exit (P6 OOB now `Dhar: index out of bounds` exit 1, never SIGSEGV; local `raw[N]` frames sized to `ceil(N/8)` slots). The parser rejects non-subset constructs (`forge`/`view`/`grab`/`trap`/`enforce`, plus `state` as reserved) with `StageAlpha 2.2` diagnostics, `todo`-gates subset-but-unimplemented (`mold` bodies/`pull`/`expose` — and since the §2.2 audit also rejects malformed ident-led statements (`y += 1`, bare `y`) as `malformed statement shape`, extra Spec1 widths (`i8`/`f32`/…) as `not in subset`, and undeclared/task/array value idents (`x = nosuch`) as `undeclared`/`expression` (call RHS `dest = fn(...)` still passes); `shift`/`cycle`/`scan`/`escape`/`skip` are implemented since 1.6.1/1.6.2), and the compiler guards all fixed tables, reports errors on stderr, and never leaves a stale `output.asm` behind. Stratified differential gate (seed 20261011, gcc oracle 160/160 agree at n=20, 480/480 at n=150 per paper): **probes 9/10 PASS + P5 correct-reject + P6 controlled-trap** (P2 probe itself aliases the output buffer — `buf[1]=66` then `buf[0]=res` leaves `[66,66,...]=16962`; with non-aliasing index `i=10` it prints `66` PASS; compiler byte/byte behavior is correct, probe expectation is flawed, see §13); **random 963/1200 PASS full-range, 1200/1200 PASS when masked to low byte** (`expected & 0xFF == got & 0xFF` on all 237 diffs at n=150 — pure `buf[0]=res` byte-width truncation, zero logic bugs; restrict published `res` to `0..255` for exact parity). The old `1200/1200 pass` claim is withdrawn.

By compiling directly to lean x86\_64 machine code with zero runtime, standard library, or GC overhead — while still executing real branchy workloads at native-tier speeds out of the box — Dhar aims to provide the deterministic foundation Stage 1 self-hosting needs. Register allocation and peephole optimization are scheduled as post-bootstrap compiler passes.


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