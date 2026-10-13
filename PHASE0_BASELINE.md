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

| Probe | Correct compiler prints | Phase-0 floor | Status |
|---|---|---|---|
| P1 local raw buffer to sys | 8 bytes (42) | 0 bytes | FAIL -> Phase 1.3 |
| P2 store vs peek stride | 66 | 0 | FAIL -> Phase 1.2 |
| P3 two-arg call add(2,3) | 5 | 5 | PASS (regression guard) |
| P4 three-arg sub3(10,3,2) | 5 | 5 | PASS (regression guard) |
| P5 identifier state | reserved: compile_reject exit 1 | reject exit 1 | BY DESIGN (Spec1 App. A); shipped tests renamed |
| P6 OOB store (informational) | diagnosable trap | SIGSEGV (exit 139) | FAIL -> Phase 1.5 |
| P7 nested when ends then-block | 0 | 7 | FAIL -> Phase 1.1 |
| P8 zero-param call + later stmts | 16 | 16 | PASS (regression guard) |
| P9 one-arg g(41) | 42 | 42 | PASS (regression guard) |
| P11 in-range store clobbers neighbor | 11 | 83 | FAIL -> Phase 1.2 |
| P12 global named out | assembles | NASM reject | FAIL -> Phase 1.4 |

## Shipped tests: 4/4 PASS (after state->st_val rename)

 foolproof (193 bytes, all [OK] lines), reference (61), showcase (57),
 test (26, "Function call successful!"). Correct branches taken.

## dharfuzz full sweep floor (seed 20261011, 150/stratum, oracle 480/480)

 1183/1200 pass, 17 failing (1.4%), 8.7s. Paper HEAD (5b9dc42): 871/1200.
 A_assign 150/150 | B_when 144/150 (6 wrong, P7 class) | C_span 150/150 |
 D_mul 149/150 (1 wrong) | E_call_0or1arg 150/150 | F_call_2args 150/150 |
 G_call_3args 150/150 | H_all_features 140/150 (10 wrong).
 Reproducers (7): B_when_58/69/74, D_mul_83, H_all_features_7/14/25.
 Raw: results.jsonl/summary.json held outside the repo (Phase-0 gate dir).

## Known-fail queue for Phase 1 (in fix order)

 1. P7 nested-when fallthrough (.check_cf_close, handle_control_flow).
 2. Byte stride: []= qword vs peek/poke byte (asm_array_store_2).
 3. P1 local-buffer lea guard (0x83) + value-form sys lea + raw[N] frame sizing.
 4. P12 identifier mangling (emit_named_operand, task labels, .bss).
 5. P6 full diagnosable bounds trap (message + clean exit, Spec1 §14.4).
 6. Structural: symbol-owner clobber, capacity guards, stderr diagnostics,
    atomic output (stale-output.asm hazard), strict subset rejection.

## Reproduce

 make linux && ./build/dharc tests/foolproof.dhar --target=linux &&
 nasm -f elf64 build/output.asm -o /tmp/o.o &&
 ld -m elf_x86_64 -o /tmp/o /tmp/o.o && /tmp/o
 python3 <dhar-popl2027-package>/artifact/dharfuzz/dharfuzz.py \
   --stage0-src src/lexer.asm --n-per-stratum 150 --seed 20261011 \
   --out /tmp/gate --validate-oracle --reduce 3
