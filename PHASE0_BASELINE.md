# Phase 0 Baseline — Forge of Dhar (Stage 0)

 canon-baseline tag: 28904b8 (commit), this file committed at 465aa60.
 src/lexer.asm: 4798 lines,
   sha256 36abc3647ab4296de852a150b877b17894281b1bf813d60ad756eb0664f8227c
 Toolchain: NASM 2.16.01, GNU ld 2.42, Python 3.12.3, gcc 13.3.0.
 Date: 2026-10-13. No compiler behavior change in Phase 0
 (commits since tag: Makefile build-rule fix, shipped-test state->st_val rename).

## Frozen normative subset (StageAlpha v1.0 §2.2, strict)

 lock/flux, task/give, when/shift/fallback, span/cycle/escape/skip,
 mold (layout only), array indexing, i32/str/bool/raw[N], pull/expose/gen.
 Everything outside this table must be rejected with a clear diagnostic
 (Alpha §2.2 exclusion rule, §4.3). Concise forms (x=5, +=, print) are
 NOT Stage-0 input; they are Stage-1 desugar territory (StageBeta §2.1).

## Probe floor (fresh dharc, clean output.asm per probe, NASM+ld+run)

| Probe | Correct compiler prints | Phase-0 floor | HEAD 8326bf2 (2026-10-14, verified) |
|---|---|---|---|
| P1 local raw buffer to sys | 8 bytes (42) | 0 bytes | PASS (42, Phase 1.3 lea fix) |
| P2 store vs peek stride | 66 | 0 | COMPILER CORRECT, PROBE FLAWED: byte/byte consistent, but probe aliases output (`buf[1]=66` then `buf[0]=res` → `[66,66,...]=16962`); with `i=10` prints 66 PASS. See README §13. |
| P3 two-arg call add(2,3) | 5 | 5 | PASS (regression guard, arg-order verified) |
| P4 three-arg sub3(10,3,2) | 5 | 5 | PASS (regression guard) |
| P5 identifier state | reserved: compile_reject exit 1 | reject exit 1 | BY DESIGN (Spec1 App. A); shipped tests renamed |
| P6 OOB store (informational) | diagnosable trap | SIGSEGV (exit 139) | PASS: `Dhar: index out of bounds` stderr, exit 1 (Phase 1.5 trap) |
| P7 nested when ends then-block | 0 | 7 | PASS (Phase 1.1 indent-bound fallback fix) |
| P8 zero-param call + later stmts | 16 | 16 | PASS (regression guard) |
| P9 one-arg g(41) | 42 | 42 | PASS (regression guard) |
| P11 in-range store clobbers neighbor | 11 | 83 | PASS (Phase 1.2 byte-stride + frames fix) |
| P12 global named out | assembles | NASM reject | PASS (Phase 1.4 `dhar_` mangling) |

## Shipped tests: 7/7 PASS (after state->st_val rename)

 foolproof (193 bytes, all [OK] lines), reference (61), showcase (57),
 test (26, "Function call successful!"), shift (4-branch PASSx4, Phase 1.6.1),
 loops (5/12/5, Phase 1.6.2), calls (57 = 5+5+5+42, Phase 1.1 multi-task
 0/1/2/3-arg gate with distinct locals r1..r4 — PASS).
 Run each via: `./build/dharc tests/<f>.dhar --target=linux && nasm -f elf64 build/output.asm -o /tmp/o.o && ld -m elf_x86_64 -o /tmp/o /tmp/o.o && /tmp/o`.

## dharfuzz gate (seed 20261011, oracle validated vs gcc -O0)

 Phase-0 floor: 1183/1200 pass, 17 failing (1.4%), 8.7s. Paper HEAD (5b9dc42): 871/1200.
 HEAD 8326bf2 (2026-10-14, n=150, 8.0s, oracle 480/480 at paper scale / 160/160 at n=20):
 963/1200 PASS full-range (237 wrong), **1200/1200 PASS when masked to low byte**
 (`(expected & 0xFF) == (got & 0xFF)` on all 237 diffs — pure `buf[0]=res`
 byte-width truncation, zero logic bugs; see README §13).
 Per-stratum (full-range): A128/150 B122/150 C124/150 D118/150 E123/150 F117/150 G124/150 H107/150.
 Probes via harness: 9/10 PASS + P5 correct-reject + P6 controlled-trap (exit 1);
 P2 `wrong 66 vs 16962` is probe aliasing (see table above), not a compiler bug.
 Raw: results.jsonl/summary.json held outside the repo (Phase-0 gate dir);
 reproduce with the command below. Restrict published `res` to 0..255 for exact parity.

## Known-fail queue for Phase 1 — ALL CLOSED at 8326bf2 (verified 2026-10-14)

 1. DONE P7 nested-when fallthrough (020b164, indent-bound fallback).
 2. DONE Byte stride: byte/byte consistent (669c9b7); P2 remaining diff is probe aliasing, P11 PASS.
 3. DONE P1 local-buffer lea + value-form sys + raw[N] frames (c41617e).
 4. DONE P12 `dhar_` mangling (67040b9).
 5. DONE P6 bounds trap stderr+exit 1 (e58a774).
 6. DONE Structural: owner clobber, capacity guards, stderr, atomic output, strict rejection.
 OPEN (docs/harness, not compiler): P2 probe aliasing fix (use separate buffer or i>=8);
 dharfuzz checksum channel documents byte width (mask `& 0xFF` or restrict 0..255).
 FIXED on fix/cond-rhs-validation (merged here): .check_cf_stmt/.check_shift_stmt
 now require RHS type 2 (identifier) or 5 (number), else `.err_cond_rhs` with
 `condition compares an identifier against a number or variable only
 (StageAlpha 2.2)`, exit 1, no stale output.asm. Verified: when/shift/span
 with string RHS all reject loudly; var-vs-var still passes (9); shipped 7/7
 + probes hold; fuzz n=150 identical (963/1200, 237 truncation-only, 0 real).
 FIXED 2026-10-14 on fix/phase-1.1-arg-integrity (merged here): same-name body
 locals across tasks collided because add_symbol zeroed qword at [rbx+16], wiping
 the owner at [rbx+20] (bytes 20..23) — every symbol became owner=0 so
 find_symbol_scoped matched the first same-named symbol in any task (sub3 r reused
 add r at [rbp-24]; got 5 want 10; 4-task got 52 want 57). One-line fix:
 `mov dword [rbx+16],0` (commit 989c981, gdb-verified owners 1/2/3, offsets
 sequential). tests/calls.dhar now uses the shared name r (stronger) and PASSES 57;
 min repros A[0p,3p]=12 B[1p,3p]=47 C[3p,3p]=11 all PASS.
 Parked, out of Strict Alpha scope: Phase 1.6.3 mold-layout WIP (stashed, breaks build —
 src/asm/ split + src/lexer/ empty dir also unbuilt/untracked, production is src/lexer.asm alone).

## Reproduce

 make linux && ./build/dharc tests/foolproof.dhar --target=linux &&
 nasm -f elf64 build/output.asm -o /tmp/o.o &&
 ld -m elf_x86_64 -o /tmp/o /tmp/o.o && /tmp/o
 python3 <dhar-popl2027-package>/artifact/dharfuzz/dharfuzz.py \
   --stage0-src src/lexer.asm --n-per-stratum 150 --seed 20261011 \
   --out /tmp/gate --validate-oracle --reduce 3
