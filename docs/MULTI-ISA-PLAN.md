# Plan: ARM64, RISC-V and WebAssembly (WASI)

**Decision recorded:** the other processors are built as back ends of the Stage 1 compiler, on its machine-independent
IR, not as extra code generators inside Stage 0. **Pending the author's confirmation** (see section 6).

## 1. Where things stand

| Target | `dharc` today |
| --- | --- |
| Linux x86-64 | Works. Native, all conformance tests pass. |
| Windows x64 | Partly. All tests pass in an emulator that enforces the Windows calling rules; not yet run on a real Windows machine. |
| ARM64, RISC-V, WASI | Not built. `dharc` refuses them with `Fatal Error: unsupported target`, exit 1, and leaves no `output.asm`. |

Refusing is deliberate. Before 22 October 2026, `--target=wasi` and an unknown target quietly produced Linux x86-64
code, which a user could mistake for the thing they asked for.

## 2. Why not in Stage 0

Stage 0 has no intermediate form. It reads a token and writes assembly text for it, and the text is x86-64 text. Its
code generator is about 3,300 lines (`codegen.asm`), and the Windows target needed a small header and one runtime stub
only because Windows x64 is the *same instruction set* with a different system interface. A different instruction set is
a different generator: a further generator of comparable size for each of ARM64, RISC-V and WebAssembly (thousands of lines of assembly
per target), all of it retired when Stage 1 gets its own back ends. The blueprint places instruction-set
back ends after the universal IR for this reason. Spending the same effort on Stage 1 gets all three targets and keeps
them.

WebAssembly adds a further reason. It has structured control flow and a stack machine, so text templates that jump to
labels do not translate; it needs an IR stage that can lay out blocks. That stage is Stage 1's job.

## 3. The plan on the IR

Order: ARM64, then RISC-V, then WebAssembly. ARM64 first because it is the most common target outside x86-64 (phones,
Apple silicon, many servers). RISC-V second because it is the smallest to emit and the most open. WebAssembly third
because it needs the block-layout work and because it unlocks the in-browser playground.

| Step | Work | Done when |
| --- | --- | --- |
| 1 | Stage 1 IR with typed values and a target-description table (A-1 R1, R4) | The IR prints and round-trips; x86-64 output through the IR equals Stage 0's output on the battery |
| 2 | **`sys` by name.** Replace numeric `sys 1, ...` with `sys.write`, `sys.exit`, `sys.read` mapped per operating system. Today's numbers are x86-64 Linux numbers. Linux ARM64 and RISC-V share one table: read 63, write 64, exit 93 | One source program emits correct calls on each target |
| 3 | ARM64 back end: AAPCS64 (arguments in x0 to x7, result in x0, 16-byte stack alignment), `svc #0` with the number in x8, ELF64 AArch64 | All battery tests pass in an emulator |
| 4 | RISC-V back end: LP64 calling convention (a0 to a7, result in a0), `ecall` with the number in a7, ELF64 RISC-V | All battery tests pass in an emulator |
| 5 | WebAssembly back end: WASI preview 1 imports `fd_write`, `fd_read`, `proc_exit`; linear memory; blocks laid out from the IR's structured control flow | All battery tests pass under a WASI runtime |
| 6 | Windows through the IR, replacing the stub-and-Linux-numbers shortcut | Same tests on a real Windows machine |

## 4. How each will be verified

The same conformance battery, run per target, as is done for Windows now.

* ARM64 and RISC-V: assemble and link with `clang`, `llvm-mc` and `lld` (all present in the build environment), run in
  the Unicorn CPU emulator, which supports both. The method is the one in `tools/pe_emulate.py`.
* WebAssembly: link with `wasm-ld`, run under Node's WASI support (Node is present) and a second runtime.
* Every target also gets a run on real hardware or a real runtime before its status can say **Works**. Emulator-only
  stays **Partly**, as Windows does.

## 5. What it costs and what it does not

* It does not delay self-hosting: steps 1 to 6 come after Stage 1 compiles itself, except step 1's IR, which Stage 1 needs
  anyway.
* It does not change the language, apart from the one Spec1 amendment in step 2 (`sys` by name), listed in the
  amendment index.
* Until then the website, README and status file show these targets as **Not yet**, and `dharc` refuses them.

## 6. The decision for the author

Option A (recommended): keep this plan. Stage 0 stays Linux x86-64 and Windows x64.

Option B: build an ARM64 code generator inside Stage 0 now, to have a second instruction set earlier. It is possible and
would be tested the same way. It costs weeks of assembly that Stage 1 will replace, and it pulls time from the
self-hosting work that the author has said comes first. It should be chosen only if an ARM64 program is needed before
Stage 1 exists.

Reply "A" or "B" (or "B for ARM64 only") and the status file, README and this plan are updated together.
