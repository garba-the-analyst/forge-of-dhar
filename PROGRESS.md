# Dhar progress log

**What this file is.** A living record of what Dhar can do *today*, kept apart from the Canon. The Canon of Dhar is a
forward-looking specification: it says what Dhar is designed to be. This file says what the compilers actually do, with
the evidence and the date. When the two disagree, this file describes the present and the Canon describes the target.
Never copy status into the Canon, and never copy a design promise into this file.

**Rules for editing**
1. Every status line has a date, a commit, and a way to re-check it (a command, a test, a number).
2. A claim is "done" only inside the boundary stated next to it. Always write the boundary.
3. Add new entries at the top of the log. Do not rewrite old ones; add a correction entry instead.
4. Numbers come from a run, not from memory. Say which run.

---

## 1. Status snapshot

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

### How to say it in public
> Stage 0 is complete **within the Strict Alpha subset** (`i32`, `str`, `bool`, `raw[N]`, tasks, branching, loops,
> `sys`, layout-only `mold`, `give` with a value or one operation). It produces programs for Linux x86-64, and for
> Windows x64 verified in an emulator. Stage 1 is scaffolding and self-hosting has not been attempted.

Use this sentence, or one with the same boundary, every time "complete" is used.

## 2. Known limits of Stage 0 (verified)

* Scalars are 64-bit slots; a published byte keeps only the low 8 bits (`buf[0] = res`). No multi-byte stores.
* `bool` is the numbers 0 and 1.
* No register allocation, no optimisation passes; variables live in `.bss`.
* `give` accepts a value or exactly one operation (`+ - * / %`) over names and numbers; longer expressions are rejected.
* Rejected by design in Stage 0: `forge`, `view`, `grab`, `state`, `trap`, `enforce`, other integer and float types, `char`, generics.
* `dharc` runs on Linux only. Targets other than `linux` and `windows` are refused with an error.
* The Windows output has been run in an emulator only, not on a real Windows machine.
* Fixed on 2026-10-22 (were present at `8a3e627`): `give a + b` returned only `a`; `gen("...")` wrote a trailing zero byte.
  Both have regression tests (14 of the 15 new tests fail on the old compiler).

## 3. Speed (generated from `benchmarks/results/`)

Workload: 1,048,576 comparisons; `hyperfine`, 3 warm-ups, 100 runs, `taskset -c 1`.

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

History: an earlier "Dhar beats C" result came from a code generation bug (loops that never ran) and was withdrawn.

## 4. Stage 1 plan (self-hosting is the only gate that matters)

**Gate.** E1 = Stage 1 source compiled by Stage 0. E2 = Stage 1 source compiled by E1. Pass when E1 and E2 are
byte-identical. Until that has been run and recorded here, nothing may be described as self-hosting.

**Rules while building Stage 1** (from the owner's decision on 2026-10-22: implement everything in the docs and reach 100%
self-hosting):
1. Freeze Spec1 syntax for the duration of Stage 1. Changes go to a decision entry first.
2. Build one construct at a time; each gets a passing test before the next begins.
3. Use only what Stage 0 accepts, so the first hand-off is possible.
4. The two Stage 0 defects that blocked `give` with expressions are fixed (2026-10-22), so Stage 1 code may use `give a + b`.

**Proposed order** (owner to confirm or change; this is a proposal, not a decision):

| # | Module (`honing-dhar/src/`) | Done when |
| --- | --- | --- |
| 1 | `lexer.dhar` | tokenises the Stage 0 battery sources to the same token stream as Stage 0 |
| 2 | `ast.dhar`, `symbol.dhar` | builds and queries a tree for the battery |
| 3 | `parser.dhar` | parses every battery program without error; rejects what Stage 0 rejects |
| 4 | `typecheck.dhar` | same accept/reject decisions as Stage 0 |
| 5 | `ir.dhar`, `codegen.dhar` | output runs and matches Stage 0 output on the battery |
| 6 | `main.dhar` | compiles itself: the E1 == E2 gate |

Reason for the order: each module can be tested on its own against Stage 0, which already acts as the oracle.

## 5. Decision log

| Date | Decision | By |
| --- | --- | --- |
| 2026-10-22 | Keep a progress log separate from the Canon; this file is it | owner |
| 2026-10-22 | Goal for Stage 1: implement everything in the docs and reach 100% self-hosting | owner |
| 2026-10-22 | Not yet decided: how to separate "designed" from "compiles today" when speaking to funders; section 1 wording is the default until then | open |

## 6. Log (newest first)

Generated from `status/status.json`; older entries below the block were written by hand and are kept as written.

<!-- gen:log:start -->
* **25 October 2026.** Website, survey and Canon moved to their own repository: The website, the survey (now a page of the website, at /survey/), the Canon documents and the progress reports live in one branch of the Dhar-website-and-docs repository, served from Render at https://dhar.onrender.com instead of GitHub Pages. This replaces the GitHub Pages step in Progress Report 001. The survey saves answers in a Supabase database; its table rules were checked on PostgreSQL (36 checks) and the page against an imitation of the service, but not yet against the live project.
* **25 October 2026.** Buffer address in `scan` fixed: Checking the Stage 1 sources against the compiler turned up a wrong stack offset: for `scan` over a local buffer the compiler wrote the buffer's address as `rbp-4294967336` instead of `rbp-40`. `nasm` warned and cut the number down to the right value, so programs printed the right answer and nothing visibly failed. The compiler now writes the right offset; two new tests check the output and the assembly text, and the assembly test fails on the previous compiler. 108 tests pass on both targets.
* **24 October 2026.** `gen(...)` is the print function: Printing no longer needs a buffer and a raw system call: `gen("text")`, `gen(42)` and `gen(name)` write a string, a number or a variable, for variables declared with a type and for ones whose type was inferred (`lock x = 5`). `gen` is strict: parentheses, exactly one argument, and a name that is an `i32`, `str` or `bool`. While testing it, a global `flux g: i32 = 77` turned out to be silently ignored (the variable stayed 0); the compiler now rejects it with a message, and it is listed as a limit, not fixed. 108 tests pass on both targets; the new tests fail on the previous compiler.
* **23 October 2026.** Negative literals in `give`: Checking the Stage 1 sources against the new compiler showed that `give -1` had always compiled as `give 0` (a silent miscompile) and that the first version of the `give` fix rejected it. It now returns the negative number, with 68 tests passing on both targets.
* **22 October 2026.** Windows x64 target: Stage 0 emits real Windows programs; unsupported targets are refused instead of silently producing Linux code. The battery grew to 64 tests and passes on both targets.
* **22 October 2026.** Two Stage 0 bugs fixed: `give a + b` used to return only `a`; `gen("...")` used to write an extra zero byte. Both fixed, with 14 tests that fail on the old compiler.
* **22 October 2026.** Direction written down: Canon Amendment A-1, a draft awaiting ratification, proposes the order: cybersecurity, then artificial intelligence, then quantum computing, each with test gates. Nothing for them is built yet.
* **22 October 2026.** Honest status in one place: One status file now drives the website, the README and the progress log, and a test fails if any of them drifts from it.
* **21 October 2026.** Website and logo: The DHAR logo and brand rules were fixed (six colours, two typefaces), and the first version of this site was built with code samples run on the real compiler. Running them also exposed the two Stage 0 bugs fixed on 22 October.
* **19 October 2026.** Test battery at 45: Positive coverage added for `gen`, `give` and `expose`.
* **18 October 2026.** Stage 0 split into nine modules: The monolithic source was divided into one-definition-per-file modules.
<!-- gen:log:end -->

* **2026-10-22 (earlier).** Created this log. Cross-checked the claims in the niche-pivot review against the repositories: bounds checking,
  `bool` as 0/1, single-byte stores, no register allocation, Stage 1 as scaffolding, self-hosting not attempted: all confirmed.
  Corrections: the "roughly 5.3x slower than C" figure is mean-based; the median figure is 15.5x. The compiler is not strictly
  "frozen": the two newest commits (18 and 19 Oct) split it into nine modules and added tests.
