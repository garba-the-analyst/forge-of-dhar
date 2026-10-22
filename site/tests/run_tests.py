#!/usr/bin/env python3
"""
run_tests.py - checks the Dhar site. Exit status 0 only if everything passed.

    python3 tests/run_tests.py [--dharc PATH] [--forge-repo PATH] [--axe PATH]

What it checks
  1. PALETTE   Only the six brand colours appear as hex values in index.html, site.css, site.js and
               every SVG in assets/logo. (A stray colour fails the run: the palette is fixed.)
  2. LOGO      tools/check_logo.py: the vector letters overlap the reference banner (>= 0.965).
  3. SAMPLES   With --dharc: each code sample on the page is compiled by the real Stage 0 compiler, linked,
               run, and its output and exit status compared with what the page shows.
  4. BENCH     With --forge-repo: the numbers on the page equal the repository's hyperfine JSON.
  5. BROWSER   Headless Chromium at 360, 768 and 1280 px: no console errors or failed requests, no
               sideways scroll, tabs work with the keyboard, the status filter and the Median/Mean
               toggle work, the copy button copies, and axe-core (with --axe) finds no violations.
Needs: Playwright with Chromium. SAMPLES also need nasm and ld.
"""
import argparse
import functools
import http.server
import json
import os
import re
import socketserver
import subprocess
import sys
import tempfile
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PALETTE = {"#0B0B0D", "#FF5C00", "#4B5563", "#22D3EE", "#C2410C", "#F3F4F6"}
CHROMIUM = os.environ.get("CHROMIUM_PATH", "/opt/pw-browsers/chromium")
fails, checks = [], 0


def check(ok, what):
    global checks
    checks += 1
    print(("  ok   " if ok else "  FAIL ") + what)
    if not ok:
        fails.append(what)


def status_counts():
    """Rows the status board must show, from status/status.json (the repo's single source of truth)."""
    for cand in (os.path.join(ROOT, "..", "status", "status.json"),):
        if os.path.exists(cand):
            import json
            comps = json.load(open(cand, encoding="utf-8"))["components"]
            return len([c for c in comps if c["status"] == "works"]), len(comps)
    return None


def bench_ratios():
    """(median ratio to C, mean ratio to C) as the page should quote them, from benchmarks/results/*.json."""
    sd = os.path.join(ROOT, "..", "status")
    if not os.path.exists(os.path.join(sd, "render.py")):
        return None
    sys.path.insert(0, sd)
    import render
    r = render.ratios(render.load_bench())
    return "%.1f" % r["median"][0], "%.1f" % r["mean"][0]


def read(p):
    return open(os.path.join(ROOT, p), encoding="utf-8").read()


def test_palette():
    print("PALETTE")
    files = ["index.html", "assets/site.css", "assets/site.js", "site.webmanifest"]
    logo = os.path.join(ROOT, "assets", "logo")
    files += ["assets/logo/" + f for f in os.listdir(logo) if f.endswith((".svg", ".html"))]
    for f in files:
        # only 6-digit hex values are colours; #main, #top, #stone etc. are ids and anchors
        found = {h.upper() for h in re.findall(r"#[0-9a-fA-F]{6}(?![0-9a-zA-Z])", read(f))}
        extra = found - PALETTE
        check(not extra, "%s uses only palette colours%s" % (f, (" (extra: %s)" % sorted(extra)) if extra else ""))
    css = read("assets/site.css")
    check(not re.search(r"\brgba?\(|\bhsla?\(|\bhwb\(|\blab\(|\blch\(|oklch\(", css), "site.css has no rgb()/hsl()/lab() literals")
    check(not re.search(r"border-radius\s*:\s*[1-9]", css), "no rounded corners in site.css")
    check("prefers-color-scheme" not in css, "single dark theme: no light-theme switch")


def test_logo():
    print("LOGO")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "check_logo.py")], capture_output=True, text=True)
    print("   " + r.stdout.strip().replace("\n", "\n   "))
    check(r.returncode == 0, "vector logo matches the reference banner")


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, **kw)


def test_samples(dharc):
    print("SAMPLES")
    page = read("index.html")
    from html import unescape
    samples = {}
    for m in re.finditer(r'<code data-sample="(\w+)">(.*?)</code>', page, re.S):
        samples[m.group(1)] = unescape(re.sub(r"<[^>]+>", "", m.group(2)))
    meta = re.findall(r'<dd>([\d,]+) bytes</dd></div><div><dt>exit status</dt><dd>(\d+)</dd>', page)
    check(len(samples) == 3 and len(meta) == 3, "three samples and three result lines on the page")
    for (name, src), (size, status) in zip(samples.items(), meta):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, "build"))
            open(os.path.join(d, name + ".dhar"), "w").write(src if src.endswith("\n") else src + "\n")
            r = run([os.path.abspath(dharc), name + ".dhar", "--target=linux"], cwd=d)
            ok = r.returncode == 0
            ok = ok and run(["nasm", "-f", "elf64", "build/output.asm", "-o", "build/%s.o" % name], cwd=d).returncode == 0
            ok = ok and run(["ld", "-m", "elf_x86_64", "-o", "build/" + name, "build/%s.o" % name], cwd=d).returncode == 0
            check(ok, "%s.dhar compiles, assembles and links" % name)
            if not ok:
                continue
            p = run(["./build/" + name], cwd=d)
            shown = re.search(r'data-output="%s">(.*?)</pre>' % name, page, re.S).group(1)
            got = (p.stdout + p.stderr).decode()
            check(got.strip() == unescape(shown).strip(), "%s output equals the page" % name)
            check(str(p.returncode) == status, "%s exit status %s equals the page" % (name, status))
            check(os.path.getsize(os.path.join(d, "build", name)) == int(size.replace(",", "")), "%s program size %s bytes" % (name, size))


def test_bench(repo):
    print("BENCH")
    data = json.loads(re.search(r'id="bench-data">(.*?)</script>', read("index.html"), re.S).group(1))
    files = {"C (raw, -O3)": "c_raw__nostdlib", "C++ (-O3)": "cpp_optimized", "Rust (release)": "rust_release", "Dhar": "dhar_native",
             "Node.js": "node.js_javascript", "PHP 8.3": "php", "Java (OpenJDK)": "java_openjdk", "Python 3": "python"}
    for g in data["groups"]:
        for r in g["rows"]:
            j = json.load(open(os.path.join(repo, "benchmarks", "results", files[r["name"]] + ".json")))["results"][0]
            ok = all(abs(r[k] - j[src] * 1000) < 0.006 for k, src in (("median", "median"), ("mean", "mean"), ("sd", "stddev")))
            check(ok, "%s matches %s.json" % (r["name"], files[r["name"]]))


def test_browser(axe):
    from playwright.sync_api import sync_playwright

    class Q(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass
    srv = socketserver.TCPServer(("127.0.0.1", 0), functools.partial(Q, directory=ROOT))
    port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    url = "http://127.0.0.1:%d/index.html" % port
    print("BROWSER")
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path=CHROMIUM, args=["--no-sandbox"])
        for w in (360, 768, 1280):
            ctx = b.new_context(viewport={"width": w, "height": 900})
            pg = ctx.new_page()
            errs = []
            pg.on("console", lambda m: errs.append(m.text) if m.type in ("error", "warning") else None)
            pg.on("pageerror", lambda e: errs.append(str(e)))
            pg.on("requestfailed", lambda r: errs.append("failed " + r.url))
            pg.goto(url)
            pg.wait_for_timeout(500)
            check(not errs, "%d px: no console errors or failed requests %s" % (w, errs or ""))
            check(pg.evaluate("document.documentElement.scrollWidth") <= w, "%d px: no sideways scroll" % w)
            check(pg.evaluate("getComputedStyle(document.body).backgroundColor") == "rgb(11, 11, 13)", "%d px: body is Forge Black" % w)
            fonts = pg.evaluate("Promise.all([document.fonts.load('400 16px Saira'), document.fonts.load('400 16px \"JetBrains Mono\"')]).then(r => r.map(x => x.length))")
            check(all(fonts), "%d px: Saira and JetBrains Mono load" % w)
            if w == 1280:
                pg.focus("#tab-loop")
                pg.keyboard.press("ArrowRight")
                check(pg.get_attribute("#tab-branch", "aria-selected") == "true" and pg.is_visible("#panel-branch") and not pg.is_visible("#panel-loop"), "tabs: ArrowRight selects Branching")
                pg.keyboard.press("End")
                check(pg.get_attribute("#tab-bounds", "aria-selected") == "true", "tabs: End selects the last tab")
                pg.click('[data-filter="works"]')
                sc = status_counts()
                if sc:
                    check(pg.locator("#board > li:visible").count() == sc[0], "filter: Works shows %d rows (status.json)" % sc[0])
                    pg.click('[data-filter="all"]')
                    check(pg.locator("#board > li:visible").count() == sc[1], "filter: All shows %d rows (status.json)" % sc[1])
                else:
                    pg.click('[data-filter="all"]')
                for sec in ("status", "progress", "direction", "language", "pipeline", "speed", "name", "survey"):
                    check(pg.locator("#" + sec).count() == 1, "section #%s exists" % sec)
                check(pg.locator("#direction .track").count() == 3 and pg.locator("#progress .timeline li").count() >= 1, "direction shows 3 tracks and progress shows milestones")
                check(pg.get_attribute("#survey a.btn", "href") == "survey/", "survey button uses the relative link survey/")
                v1 = pg.inner_text("#verdict")
                pg.click('[data-metric="mean"]')
                v2 = pg.inner_text("#verdict")
                br = bench_ratios()
                check("median" in v1 and "mean" in v2 and (not br or (br[1] in v2 and br[0] in v1)), "speed: toggle changes the verdict and quotes the JSON-derived ratios %s (%s | %s)" % (br, v1[:40], v2[:40]))
                ctx.grant_permissions(["clipboard-read", "clipboard-write"], origin="http://127.0.0.1:%d" % port)
                pg.click("#tab-loop")
                pg.click("#panel-loop .copy")
                try:
                    txt = pg.evaluate("navigator.clipboard.readText()")
                    check(txt.startswith("task core():") and "Limit reached" in txt, "copy button puts the sample on the clipboard")
                except Exception as e:
                    check(False, "copy button: clipboard unreadable (%s)" % e)
                if axe and os.path.exists(axe):
                    pg.add_script_tag(path=axe)
                    res = pg.evaluate("axe.run().then(r => r.violations.map(v => v.id + ': ' + v.nodes.length + ' ' + v.nodes[0].target.join(' ')))")
                    check(not res, "axe-core: no violations %s" % (res or ""))
            ctx.close()
        b.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dharc")
    ap.add_argument("--forge-repo")
    ap.add_argument("--axe")
    a = ap.parse_args()
    test_palette()
    test_logo()
    if a.dharc:
        test_samples(a.dharc)
    else:
        print("SAMPLES skipped (no --dharc)")
    if a.forge_repo:
        test_bench(a.forge_repo)
    else:
        print("BENCH skipped (no --forge-repo)")
    test_browser(a.axe)
    print("\n%d checks, %d failed" % (checks, len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
