#!/usr/bin/env python3
"""
test_status.py - the honesty test. Fails if anything the project says about itself is out of step with
the code or with its own single source of truth.

    python3 tests/test_status.py            full run (builds dharc, runs the Linux battery; the Windows battery
                                            too when lld-link, llvm-dlltool and the Python packages unicorn and
                                            pefile are present)
    python3 tests/test_status.py --fast     skips building and running the batteries

What it checks
  1. Generated blocks (README, benchmarks/README, PROGRESS) match status/status.json and
     benchmarks/results/*.json exactly                              -> run `python3 status/render.py`
  2. facts.battery_total in status.json equals the number of tests a real run reports, per target
  3. every status word is one of the four allowed, and every id is unique
  4. (moved) the check that every gate id is written up in Canon Amendment A-1 now lives with the Canon, in
     the Dhar-website-and-docs repository (tests/run_tests.py there)
  5. no retired or unverifiable claim has crept back into a public document
  6. no document claims that Dhar beats or is faster than C
  (The website is in the Dhar-website-and-docs repository and is checked there against a copy of status.json.)
Exit status is 0 only if every check passed.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails, checks = [], 0


def check(ok, what):
    global checks
    checks += 1
    print(("  ok   " if ok else "  FAIL ") + what)
    if not ok:
        fails.append(what)


def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()


def run(cmd, env=None, timeout=600):
    e = dict(os.environ)
    if env:
        e.update(env)
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, env=e, timeout=timeout)


# Phrases that were retired because they were false, unverifiable or out of date. Keep this list growing.
RETIRED = [
    ("fastest entry among", "unverifiable speed claim"),
    ("SCAFFOLDING ONLY", "Windows target is no longer scaffolding"),
    ("Code Generator Scaffolding Active", "old target-matrix wording"),
    ("45 of 45", "old battery count"),
    ("45 cases", "old battery count"),
    ("Turing-complete foundation required", "aspirational claim stated as fact"),
    (r"\pm 4.93", "LaTeX leftover in the README"),
    ("still emits Linux ELF", "windows/wasi no longer fall back to Linux"),
    ("roughly **5x behind", "mean-only speed framing"),
]
PUBLIC_DOCS = ["README.md", "PROGRESS.md", "benchmarks/README.md", "PHASE0_BASELINE.md"]


def test_generated():
    print("GENERATED BLOCKS")
    r = run([sys.executable, "status/render.py", "--check"])
    print("   " + (r.stdout + r.stderr).strip())
    check(r.returncode == 0, "README, benchmarks/README and PROGRESS match status.json and benchmarks/results")


def test_vocabulary():
    print("STATUS FILE")
    st = json.load(open(os.path.join(ROOT, "status", "status.json"), encoding="utf-8"))
    allowed = {"works", "partly", "designed", "notyet"}
    used = ([c["status"] for c in st["components"]] + [p["status"] for p in st["pipeline"]] +
            [b["status"] for b in st["backends"]] + [g["status"] for t in st["tracks"] for g in t["gates"]])
    check(set(used) <= allowed, "every status word is one of works, partly, designed, notyet")
    ids = [c["id"] for c in st["components"]]
    check(len(ids) == len(set(ids)), "component ids are unique")
    gate_ids = [g["id"] for t in st["tracks"] for g in t["gates"]]
    check(len(gate_ids) == len(set(gate_ids)), "gate ids are unique")
    dates = [m["date"] for m in st["milestones"]]
    check(dates == sorted(dates, reverse=True), "milestones are newest first")
    check(all(m["date"] <= st["as_of"] for m in st["milestones"]), "no milestone is dated after as_of")
    return st


def test_batteries(st):
    print("BATTERIES")
    b = run(["make", "linux"])
    check(b.returncode == 0, "dharc builds from source")
    want = st["facts"]["battery_total"]
    r = run(["./tests/conformance_alpha.sh"])
    m = re.search(r"RESULT \(linux\): (\d+) passed, (\d+) failed", r.stdout)
    check(bool(m) and int(m.group(1)) == want and int(m.group(2)) == 0,
          "Linux battery: %s (status.json says %d, all must pass)" % (m.group(0) if m else "no result line", want))
    have = all(shutil.which(x) for x in ("lld-link", "llvm-dlltool")) and \
        run([sys.executable, "-c", "import unicorn, pefile"]).returncode == 0
    if have:
        r = run(["./tests/conformance_alpha.sh"], env={"TARGET": "windows"})
        m = re.search(r"RESULT \(windows\): (\d+) passed, (\d+) failed", r.stdout)
        check(bool(m) and int(m.group(1)) == want and int(m.group(2)) == 0,
              "Windows battery (emulated): %s (status.json says %d)" % (m.group(0) if m else "no result line", want))
    else:
        print("  skip Windows battery: needs lld-link, llvm-dlltool and pip packages unicorn, pefile")
    mods = len([f for f in os.listdir(os.path.join(ROOT, "src", "asm")) if f.endswith(".asm")])
    check(mods == st["facts"]["dharc_modules"], "src/asm has %d modules (status.json says %d)" % (mods, st["facts"]["dharc_modules"]))


def test_claims():
    print("CLAIMS")
    for p in PUBLIC_DOCS:
        if not os.path.exists(os.path.join(ROOT, p)):
            continue
        text = read(p)
        bad = [why for phrase, why in RETIRED if phrase in text]
        check(not bad, "%s has no retired claim %s" % (p, bad or ""))
    # the speed section must not say 'beats C' or 'faster than C'
    check(not re.search(r"(beats|faster than) C\b", read("README.md")), "no claim that Dhar beats or is faster than C")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fast", action="store_true")
    a = ap.parse_args()
    test_generated()
    st = test_vocabulary()
    if not a.fast:
        test_batteries(st)
    test_claims()
    print("\n%d checks, %d failed" % (checks, len(fails)))
    for f in fails:
        print("  FAILED: " + f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
