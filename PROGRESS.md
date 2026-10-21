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

## 1. Status snapshot (checked 2026-10-21)

| Area | Status | Boundary | Evidence |
| --- | --- | --- | --- |
| Stage 0 (`forge-of-dhar`, NASM x86-64) | Works | Strict Alpha §2.2 subset only | commit `8a3e627`; battery 45/45 |
| Output target | Linux x86-64 only | `windows` and `wasi` parse but emit no working code | README target matrix |
| Build reproducibility | Same source gives a byte-identical `dharc` | two clean builds, same sha256 (2026-10-22) | `nasm -f elf64 src/asm/entry.asm` then `ld -m elf_x86_64` |
| Bounds checking | Works on `raw[N]` stores | trap prints `Dhar: index out of bounds`, exit 1 | sample `bounds.dhar` |
| Stage 1 (`honing-dhar`) | Scaffolding | 8 files, all assemble through Stage 0, none is a working compiler | commit `cfa336b`, "8/8 ASM-OK" |
| Self-hosting (E1 == E2) | Not attempted | | |
| Optimiser | None | every variable in memory, no register allocation | README §Benchmark |
| Modules, std library, `Kun` | None | `pull`/`expose` validated, one file only | README §11 |

### How to say it in public
> Stage 0 is complete **within the Strict Alpha subset** (`i32`, `str`, `bool`, `raw[N]`, tasks, branching, loops,
> `sys`, layout-only `mold`). It targets Linux x86-64. Stage 1 is scaffolding and self-hosting has not been attempted.

Use this sentence, or one with the same boundary, every time "complete" is used.

## 2. Known limits of Stage 0 (verified)

* Scalars are 64-bit slots; a published byte keeps only the low 8 bits (`buf[0] = res`). No multi-byte stores.
* `bool` is the numbers 0 and 1.
* No register allocation, no optimisation passes; variables live in `.bss`.
* Rejected by design in Stage 0: `forge`, `view`, `grab`, `state`, `trap`, `enforce`, other integer and float types, `char`, generics.
* Two defects found by running the compiler on 2026-10-21 (still present at `8a3e627`):
  1. `give a + b` returns the first operand only (the expression is mis-compiled without an error).
  2. `gen("...")` emits a trailing NUL byte after the text.

## 3. Speed (re-run before quoting)

Workload: 1,048,576 comparisons; `hyperfine`, 3 warm-ups, 100 runs, `taskset -c 1`; JSON in `benchmarks/results/`.

| | Median | Mean |
| --- | --- | --- |
| C (raw, -O3) | 0.47 ms | 1.58 ms |
| Dhar | 7.28 ms | 8.40 ms |
| Dhar relative to C | **15.5x slower** | **5.3x slower** |
| Node.js, PHP, Java, Python relative to Dhar | 11.7x to 20.3x slower | 11.7x to 21.5x slower |

Quote **both** columns. The mean-only figure (5.3x) flatters Dhar because process start-up noise is as large as the work at
this scale; the median figure (15.5x) is the steadier one. History: an earlier "Dhar beats C" result came from a code
generation bug (loops that never ran) and was withdrawn.

## 4. Stage 1 plan (self-hosting is the only gate that matters)

**Gate.** E1 = Stage 1 source compiled by Stage 0. E2 = Stage 1 source compiled by E1. Pass when E1 and E2 are
byte-identical. Until that has been run and recorded here, nothing may be described as self-hosting.

**Rules while building Stage 1** (from the owner's decision on 2026-10-22: implement everything in the docs and reach 100%
self-hosting):
1. Freeze Spec1 syntax for the duration of Stage 1. Changes go to a decision entry first.
2. Build one construct at a time; each gets a passing test before the next begins.
3. Use only what Stage 0 accepts, so the first hand-off is possible.
4. Fix the two Stage 0 defects in section 2 first, because Stage 1 code will use `give` with expressions.

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

* **2026-10-22.** Created this log. Cross-checked the claims in the niche-pivot review against the repositories: bounds checking,
  `bool` as 0/1, single-byte stores, no register allocation, Stage 1 as scaffolding, self-hosting not attempted: all confirmed.
  Corrections: the "roughly 5.3x slower than C" figure is mean-based; the median figure is 15.5x. The compiler is not strictly
  "frozen": the two newest commits (18 and 19 Oct) split it into nine modules and added tests.
* **2026-10-21.** Built the Dhar website and logo. Compiled and ran its three code samples with the real `dharc`; all matched
  (core 9,128 bytes, branch 9,344, bounds 9,080, exit 1). Found the two defects in section 2. Re-read benchmark JSON.
* **2026-10-19.** `8a3e627`: battery 45/45, positive coverage for `gen`, `give`, `expose`.
* **2026-10-18.** `f14e214`: Stage 0 split into nine one-definition-per-file modules.
