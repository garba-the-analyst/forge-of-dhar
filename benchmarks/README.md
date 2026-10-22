# **Dhar Objective Benchmark Suite & Telemetry Architecture**

This documentation covers the automated comparative benchmarking suite for Dhar. It is designed to rigorously evaluate Dhar's execution speed and hardware throughput against compiled system languages, JIT runtimes, and interpreted engines.

## **1. How to Run the Benchmark Tests**

The entire benchmarking process is automated via a master Python harness named `orchestrator.py`.

*   **Execution Command:** To run the full suite, execute the Python script from your terminal using `python3 orchestrator.py`.
*   **Build Phase:** The orchestrator will automatically compile the source code for all target languages (such as invoking `gcc`, `g++`, `rustc`, and `javac`). The Dhar workload is compiled by the freshly built Stage 0 engine (`./build/dharc`) before timing begins. NOTE (honesty, 2026-10-14): `benchmarks/runners/*.sh` are 0-byte dead stubs — `orchestrator.py` is the real harness. Its build string assumes `build/output.asm` relative paths; run it from the repo root and verify fresh `output.asm` per language (stale-output hazard, cf. Phase 1.5b unlink fix).
*   **Telemetry Generation:** After building, the script runs the benchmarking matrix using `hyperfine`.
*   **Output:** The raw execution traces and JSON telemetry outputs are automatically exported and stored in the `benchmarks/results/` directory.

**Prerequisites:** `python3`, `hyperfine`, `nasm`, `ld`, `gcc`, `g++`, `rustc`, `javac`/`java`, `node`, `php`, `taskset`.

## **2. Engineering Methodology & Environmental Isolation**

To prevent architectural bias, CPU frequency scaling variance, or operating system jitter, the framework enforces the following controls:

*   **Core Pinning:** All workloads are executed with the `taskset -c 1` command. This strictly locks execution to a single physical CPU core, preventing the Linux scheduler from migrating threads and eliminating cross-socket latency and cache invalidation overhead.
*   **Statistical Rigor:** The orchestrator uses the `hyperfine` tool to prevent anomalies from single-run timings. Each test includes a mandatory 3-run warm-up phase to populate caches, followed by 100 consecutive runs to compute accurate statistical metrics.
*   **Measurement Noise Floor (Honesty Note):** At single-digit-millisecond scale, process startup and scheduler jitter contribute significantly to observed timings. For the compiled tier this yields a standard deviation on the same order as the mean; **medians are the more stable indicator** for sub-10 ms entries. Rankings within the native tier should be treated as directional rather than exact.

## **3. The Standardized Workload Algorithm**

To ensure absolute parity, every language competitor executes an identical computational workload: a high-throughput delimiter-scanning simulation modeled on lexer token parsing.

*   **Iteration Scale:** 16 outer loop cycles x 65,536 inner iterations = **1,048,576 total condition evaluations** per run.
*   **Simulated Stream:** An 8-bit counter cycles through values 0-255 per iteration (wraparound via explicit comparison), emulating a byte stream without requiring an actual buffer allocation.
*   **Conditionals:** Each iteration evaluates nested equality checks against ASCII whitespace delimiters (32 = space, 10 = newline) and increments a token counter on match.
*   **Parity Check:** All implementations perform identical branch structure, arithmetic, and counter updates; only the host language differs.

Workload sources: `benchmarks/workloads/test.dhar`, `test.c`, `test.cpp`, `test.rs`, `Test.java`, `test.js`, `test.php`, `test.py`.

## **4. Performance Leaderboard**

The table is generated from the JSON files in `results/` by `python3 status/render.py`; do not edit it by hand. Median is the steadier figure at this scale (see the noise note in section 2); the mean carries process start-up jitter.

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

History: earlier tables in this file (V0.2.3, with Dhar at 9.3 ms mean and 8.2 ms median) were replaced when `results/` was refreshed for V0.3.0. Pre-V0.3.0 results that had Dhar beating C were caused by a code-generation bug (loops that never ran) and were withdrawn.

## **5. Architectural Findings & Conclusion**

*   **Native-Tier Placement:** Dhar executes this branchy scalar workload at native-tier speed with **zero optimization passes** — well behind auto-vectorized `-O3` C and far ahead of V8, the JVM, PHP and CPython (the ratios are in the table above, generated from the JSON).
*   **Why the Gap to C Is Expected:** The Stage 0 engine emits naive scalar assembly. Every variable is memory-resident (.bss), there is no register allocation, no instruction scheduling, no strength reduction, and no SIMD auto-vectorization. GCC heavily vectorizes this specific scan loop; Dhar performs one comparison and one memory round-trip per iteration. Closing this gap is post-bootstrap work (register allocation, peephole passes), not a limitation of the language design.
*   **Zero Abstraction Tax Still Applies:** Dhar's numbers are achieved with no standard library, no runtime layer, no GC, and direct kernel syscalls — a ~10 KB static binary versus multi-megabyte JIT runtime footprints.
*   **Tiered Efficiency:** The telemetry clearly demarcates AOT-compiled languages (< 10 ms) from JIT and interpreted engines (> 60 ms). Dhar sits unambiguously in the former tier.

## **6. Telemetry Changelog**

*   **V0.3.0 (current):** Implemented full stack-frame support with task-local variables, parameter passing (System V AMD64 ABI, up to 6 args), `give` returns, and proper recursion. Added `poke` (byte store) and completed `peek`/`sysret`. Fixed all relational operators (`==`, `!=`, `<`, `>`, `<=`, `>=`) with correct conditional jumps and variable-to-variable memory compares. Added strength-reduction folds (`x = x + 1` → `inc`). Retired all pre-V0.3.0 telemetry — previous "Dhar beats C" results were artifacts of a codegen bug where `span <` loops silently never executed.
*   **V0.2.3:** Fixed inverted conditional-jump codegen for relational operators... (as above)
