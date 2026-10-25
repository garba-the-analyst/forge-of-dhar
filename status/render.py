#!/usr/bin/env python3
"""
render.py - regenerates every place that states what Dhar can do, from two sources of truth:

    status/status.json            what works, what is designed, milestones   (edited by hand)
    benchmarks/results/*.json     the hyperfine measurements                 (produced by the benchmark run)

Run it after editing either, then commit the result:

    python3 status/render.py            rewrite the generated blocks
    python3 status/render.py --check    change nothing; exit 1 if any block is out of date

Generated blocks sit between markers like  <!-- status:board:start -->  and  <!-- status:board:end -->
(Markdown and HTML comments, so they are invisible when rendered). Never edit inside a block by hand:
the next run overwrites it. tests/test_status.py runs this with --check, so a stale README or
progress log fails the tests.

The website (https://dhar.onrender.com) is in its own repository, Dhar-website-and-docs, which keeps a copy
of status.json and the benchmark JSON (tools/sync_from_forge.py there) and renders its own pages from them.
This file no longer writes any website file.

Targets
    README.md              status table, speed table
    benchmarks/README.md   speed table
    PROGRESS.md            status table, speed table, milestone log
"""
import argparse
import html
import json
import os
import re
import subprocess
import sys
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LABEL = {"works": "Works", "partly": "Partly", "designed": "Designed", "notyet": "Not yet"}

BENCH_FILES = [  # (display name, result file, group)
    ("C (raw, -O3)", "c_raw__nostdlib", "Compiled ahead of time"),
    ("C++ (-O3)", "cpp_optimized", "Compiled ahead of time"),
    ("Rust (release)", "rust_release", "Compiled ahead of time"),
    ("Dhar", "dhar_native", "Compiled ahead of time"),
    ("Node.js", "node.js_javascript", "Runtimes"),
    ("PHP 8.3", "php", "Runtimes"),
    ("Java (OpenJDK)", "java_openjdk", "Runtimes"),
    ("Python 3", "python", "Runtimes"),
]


def load_status():
    with open(os.path.join(ROOT, "status", "status.json"), encoding="utf-8") as f:
        return json.load(f)


def load_bench():
    out = []
    for name, fn, group in BENCH_FILES:
        with open(os.path.join(ROOT, "benchmarks", "results", fn + ".json"), encoding="utf-8") as f:
            r = json.load(f)["results"][0]
        out.append({"name": name, "group": group, "median": round(r["median"] * 1000, 2),
                    "mean": round(r["mean"] * 1000, 2), "sd": round(r["stddev"] * 1000, 2), "us": name == "Dhar"})
    return out


def forge_commit():
    """Short hash of the last commit that changed the compiler, its tests or its build rules."""
    try:
        return subprocess.run(["git", "log", "-1", "--format=%h", "--", "src", "tests", "Makefile"],
                              cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        return "unknown"


def subst(text, st):
    return re.sub(r"\{(\w+)\}", lambda m: str(st["facts"].get(m.group(1), m.group(0))), text)




def long_date(iso):
    d = date.fromisoformat(iso)
    return "%d %s %d" % (d.day, d.strftime("%B"), d.year)


def short_date(iso):
    d = date.fromisoformat(iso)
    return "%d %s %d" % (d.day, d.strftime("%b"), d.year)


def ratios(bench):
    by = {b["name"]: b for b in bench}
    d, c = by["Dhar"], by["C (raw, -O3)"]
    rt = [by[n] for n in ("Node.js", "PHP 8.3", "Java (OpenJDK)", "Python 3")]
    res = {}
    for k in ("median", "mean"):
        f = [r[k] / d[k] for r in rt]
        res[k] = (d[k] / c[k], min(f), max(f))
    return res


def x1(v):
    return "%.1fx" % v


# ----------------------------------------------------------------------------- HTML pieces












# ----------------------------------------------------------------------------- Markdown pieces
def md_status(st):
    lines = ["| Area | Status | What it means today |", "| --- | --- | --- |"]
    for c in st["components"]:
        lines.append("| %s | **%s** | %s |" % (c["title"], LABEL[c["status"]], subst(c["text"], st).replace("|", "\\|")))
    lines.append("")
    lines.append("Status checked %s against commit `%s`. Words: **Works** = runs and is tested; **Partly** = some of it runs and is tested; "
                 "**Designed** = specified or scaffolded, not working; **Not yet** = nothing exists. "
                 "Generated from `status/status.json` (see HONESTY.md in the Dhar-website-and-docs repository)." % (long_date(st["as_of"]), forge_commit()))
    return "\n".join(lines)


def md_speed(bench):
    r = ratios(bench)
    c = {b["name"]: b for b in bench}["C (raw, -O3)"]
    lines = ["| Rank | Language / runtime | Median | Mean | Std dev | vs C (median) | vs C (mean) |", "| ---: | --- | ---: | ---: | ---: | ---: | ---: |"]
    for i, b in enumerate(sorted(bench, key=lambda b: b["median"]), 1):
        nm = "**%s**" % b["name"] if b["us"] else b["name"]
        lines.append("| %d | %s | %.2f ms | %.2f ms | %.2f ms | %s | %s |" % (
            i, nm, b["median"], b["mean"], b["sd"], "1.0x" if b is c else x1(b["median"] / c["median"]), "1.0x" if b is c else x1(b["mean"] / c["mean"])))
    lines.append("")
    lines.append("Dhar is **%s slower than C by the median** (%s by the mean) and **%s to %s faster than Node.js, PHP, Java and Python by the median** (%s to %s by the mean). "
                 "Quote both columns: at a millisecond or two, process start-up and scheduler noise are as large as the work, so the mean flatters Dhar against C and the median is the steadier figure. "
                 "One workload only (1,048,576 comparisons), `hyperfine` 100 runs after 3 warm-ups, pinned with `taskset -c 1`; whole-process time. Generated from `benchmarks/results/*.json`."
                 % (x1(r["median"][0]), x1(r["mean"][0]), x1(r["median"][1]), x1(r["median"][2]), x1(r["mean"][1]), x1(r["mean"][2])))
    return "\n".join(lines)


def md_log(st):
    return "\n".join("* **%s.** %s: %s" % (long_date(m["date"]), m["title"], subst(m["text"], st)) for m in st["milestones"])


# ----------------------------------------------------------------------------- block replacement
def replace_block(text, name, body, comment="html"):
    start, end = "<!-- %s:start -->" % name, "<!-- %s:end -->" % name
    pat = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)
    if not pat.search(text):
        raise SystemExit("marker %s missing" % start)
    return pat.sub(lambda m: start + "\n" + body + "\n" + end, text, count=1)


def replace_inline(text, name, value):
    pat = re.compile(r"<!--%s-->.*?<!--/%s-->" % (name, name), re.S)
    return pat.sub(lambda m: "<!--%s-->%s<!--/%s-->" % (name, value, name), text)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    st, bench = load_status(), load_bench()
    commit = forge_commit()
    jobs = {}

    # --- markdown
    for p, blocks in (("README.md", {"status": md_status(st), "speed": md_speed(bench)}),
                      ("benchmarks/README.md", {"speed": md_speed(bench)}),
                      ("PROGRESS.md", {"status": md_status(st), "speed": md_speed(bench), "log": md_log(st)})):
        t = open(os.path.join(ROOT, p), encoding="utf-8").read()
        for name, body in blocks.items():
            t = replace_block(t, "gen:" + name, body)
        jobs[p] = t

    stale = []
    for p, new in jobs.items():
        full = os.path.join(ROOT, p)
        old = open(full, encoding="utf-8").read()
        if old != new:
            stale.append(p)
            if not a.check:
                open(full, "w", encoding="utf-8").write(new)
    if a.check:
        if stale:
            print("OUT OF DATE (run python3 status/render.py): " + ", ".join(stale))
            return 1
        print("status blocks are up to date")
        return 0
    print("updated: " + (", ".join(stale) if stale else "nothing (already current)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
