#!/bin/bash
# StageAlpha §2.2 conformance battery for the Forge of Dhar (Stage 0).
# Positive cases must compile+assemble+link+run with exact checksums;
# negative cases must fail with exit!=0, a diagnostic on stderr, and no
# build/output.asm left behind. See PHASE0_BASELINE.md for the gate table.
# Usage: ./tests/conformance_alpha.sh  (from the repo root; needs nasm/ld/python3)
cd "$(dirname "$0")/.." || exit 1
PASS=0; FAIL=0; NOTES=()
t() { # t <name> <expect:run|reject> <dhar-file-content via stdin>
  local name="$1" expect="$2"
  echo "$3" > /tmp/case.dhar
  rm -f build/output.asm
  ./build/dharc /tmp/case.dhar --target=linux > /tmp/c.o.txt 2>/tmp/c.e.txt
  local dharc_ec=$?
  local msg; msg=$(strings /tmp/c.e.txt | grep -a -o -m1 "Syntax Error.*\|Semantic Error.*\|Fatal Error.*" | head -c 90)
  if [ "$expect" = run ]; then
    if [ $dharc_ec -eq 0 ] && [ -s build/output.asm ] && nasm -f elf64 build/output.asm -o /tmp/c.o 2>/dev/null && ld -m elf_x86_64 -o /tmp/c /tmp/c.o 2>/dev/null; then
      if timeout 5 /tmp/c > /tmp/c.bin 2>/dev/null; then
        local got; got=$(python3 -c "import struct,sys; d=open('/tmp/c.bin','rb').read(); print(struct.unpack('<Q',d[:8])[0] if len(d)>=8 else len(d))")
        if [ "$got" = "$4" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); NOTES+=("$name: RAN but got $got want $4"); fi
      else FAIL=$((FAIL+1)); NOTES+=("$name: runtime crash"); fi
    else FAIL=$((FAIL+1)); NOTES+=("$name: failed to build (dharc_ec=$dharc_ec $msg)"); fi
  else # expect reject
    if [ $dharc_ec -ne 0 ] && [ ! -f build/output.asm ] && [ -n "$msg" ]; then PASS=$((PASS+1));
    else FAIL=$((FAIL+1)); NOTES+=("$name: NOT rejected (ec=$dharc_ec outasm=$([ -f build/output.asm ] && echo present || echo absent) msg='$msg')"); fi
  fi
}
# ---- POSITIVE: bindings ----
t "lock-use" run 'flux buf: raw[8]
task core():
    lock five: i32 = 5
    flux z: i32 = 0
    flux res: i32 = 0
    res = five + 1
    buf[z] = res
    sys 1, 1, buf, 8' 6
t "lock-reassign-reject" reject 'flux buf: raw[8]
task core():
    lock five: i32 = 5
    flux z: i32 = 0
    five = 6
    buf[z] = five
    sys 1, 1, buf, 8'
t "flux-arith" run 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux a: i32 = 20
    flux b: i32 = 6
    flux r: i32 = 0
    r = a + b
    r = r - a
    r = r * b
    r = r / b
    buf[z] = r
    sys 1, 1, buf, 8' 6
# ((20+6)-20)=6; 6*6=36; 36/6=6
t "bool-decl" run 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux res: i32 = 0
    flux b: bool = 1
    when b == 1:
        res = 7
    fallback:
        res = 1
    buf[z] = res
    sys 1, 1, buf, 8' 7
t "str-use" run 'flux buf: raw[8]
task core():
    lock m: str = "hi"
    flux z: i32 = 0
    flux res: i32 = 42
    buf[z] = res
    sys 1, 1, buf, 8' 42
# ---- POSITIVE: six relational ops ----
t "six-ops" run 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux res: i32 = 0
    flux a: i32 = 5
    when a == 5:
        res = res + 1
    when a != 4:
        res = res + 1
    when a < 6:
        res = res + 1
    when a > 4:
        res = res + 1
    when a <= 5:
        res = res + 1
    when a >= 5:
        res = res + 1
    buf[z] = res
    sys 1, 1, buf, 8' 6
t "shift-fallback" run 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux res: i32 = 0
    flux v: i32 = 2
    when v == 1:
        res = 10
    shift v == 2:
        res = 20
    fallback:
        res = 30
    buf[z] = res
    sys 1, 1, buf, 8' 20
t "span-loop" run 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux res: i32 = 0
    flux i: i32 = 0
    span i < 5:
        res = res + i
        i = i + 1
    buf[z] = res
    sys 1, 1, buf, 8' 10
t "cycle-escape" run 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux i: i32 = 0
    cycle:
        i = i + 1
        when i == 4:
            escape
    buf[z] = i
    sys 1, 1, buf, 8' 4
t "skip" run 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux s: i32 = 0
    flux k: i32 = 0
    span k < 5:
        k = k + 1
        when k == 3:
            skip
        s = s + k
    buf[z] = s
    sys 1, 1, buf, 8' 12
# 1+2+4+5=12
echo 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux res: i32 = 77
    gen("x")
    buf[z] = res
    sys 1, 1, buf, 8' > /tmp/case.dhar
rm -f build/output.asm
./build/dharc /tmp/case.dhar --target=linux > /dev/null 2>&1
nasm -f elf64 build/output.asm -o /tmp/c.o && ld -m elf_x86_64 -o /tmp/c /tmp/c.o && timeout 5 /tmp/c > /tmp/c.bin
if python3 -c "import sys; d=open('/tmp/c.bin','rb').read(); sys.exit(0 if d==b'xM\x00\x00\x00\x00\x00\x00\x00' else 1)"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); NOTES+=("gen: wrong bytes"); fi
echo 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux i: i32 = 99
    buf[i] = z
    buf[z] = z
    sys 1, 1, buf, 8' > /tmp/case.dhar
rm -f build/output.asm
./build/dharc /tmp/case.dhar --target=linux > /dev/null 2>&1
nasm -f elf64 build/output.asm -o /tmp/c.o && ld -m elf_x86_64 -o /tmp/c /tmp/c.o && timeout 5 /tmp/c > /tmp/c.bin 2>/tmp/c.err
if [ $? -eq 1 ] && grep -a -q "index out of bounds" /tmp/c.err; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); NOTES+=("oob-trap: no runtime trap"); fi
t "sysret" run 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux res: i32 = 0
    sys 1, 1, buf, 0
    sysret res
    buf[z] = 9
    sys 1, 1, buf, 8' 9
t "peek-poke" run 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux b: raw[8]
    flux v: i32 = 65
    flux i: i32 = 3
    flux got: i32 = 0
    poke b, i, v
    peek got, b, i
    buf[z] = got
    sys 1, 1, buf, 8' 65
# oob-trap: RUNTIME trap by design (exit 1 + stderr, no segfault) — verified below
# ---- Subset-but-todo ----
t "mold-empty" reject 'flux buf: raw[8]
mold Point {
}
task core():
    flux z: i32 = 0
    buf[z] = z
    sys 1, 1, buf, 8'
t "pull" reject 'pull math
flux buf: raw[8]
task core():
    flux z: i32 = 0
    buf[z] = z
    sys 1, 1, buf, 8'
t "expose" reject 'expose dist
flux buf: raw[8]
task core():
    flux z: i32 = 0
    buf[z] = z
    sys 1, 1, buf, 8'
# ---- NEGATIVE: non-subset ----
t "forge" reject 'forge Point {
}
flux buf: raw[8]
task core():
    flux z: i32 = 0
    buf[z] = z
    sys 1, 1, buf, 8'
t "view" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    view z
    buf[z] = z
    sys 1, 1, buf, 8'
t "grab" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    grab z
    buf[z] = z
    sys 1, 1, buf, 8'
t "trap" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    trap z
    buf[z] = z
    sys 1, 1, buf, 8'
t "enforce" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    enforce z
    buf[z] = z
    sys 1, 1, buf, 8'
t "state-ident" reject 'flux buf: raw[8]
task core():
    flux state: i32 = 1
    flux z: i32 = 0
    buf[z] = z
    sys 1, 1, buf, 8'
t "i8-type" reject 'flux buf: raw[8]
task core():
    flux x: i8 = 1
    flux z: i32 = 0
    buf[z] = z
    sys 1, 1, buf, 8'
t "f32-type" reject 'flux buf: raw[8]
task core():
    flux x: f32 = 1
    flux z: i32 = 0
    buf[z] = z
    sys 1, 1, buf, 8'
t "concise-assign" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    y = 10
    buf[z] = z
    sys 1, 1, buf, 8'
t "plus-eq" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux y: i32 = 1
    y += 1
    buf[z] = y
    sys 1, 1, buf, 8'
t "str-cond" reject 'flux buf: raw[8]
task core():
    flux w: i32 = 1
    flux z: i32 = 0
    flux res: i32 = 0
    when w == "task":
        res = 1
    buf[z] = res
    sys 1, 1, buf, 8'
t "escape-outside" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    escape
    buf[z] = z
    sys 1, 1, buf, 8'
t "skip-outside" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    skip
    buf[z] = z
    sys 1, 1, buf, 8'
t "shift-orphan" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux v: i32 = 1
    shift v == 1:
        z = 1
    buf[z] = z
    sys 1, 1, buf, 8'
t "fallback-alone" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    fallback:
        z = 1
    buf[z] = z
    sys 1, 1, buf, 8'
t "empty-span" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux i: i32 = 0
    span i < 5:
    buf[z] = z
    sys 1, 1, buf, 8'
t "undeclared" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    nosuch = 1
    buf[z] = z
    sys 1, 1, buf, 8'
t "redeclare" reject 'flux buf: raw[8]
task core():
    flux z: i32 = 0
    flux z: i32 = 1
    buf[z] = z
    sys 1, 1, buf, 8'
echo "=== RESULT: $PASS passed, $FAIL failed ==="
for n in "${NOTES[@]}"; do echo "GAP: $n"; done
