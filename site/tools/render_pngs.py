#!/usr/bin/env python3
"""
render_pngs.py - turns the SVG logos made by build_logo.py into PNG and ICO files.

Run build_logo.py first. Then:   python3 tools/render_pngs.py
Needs: Playwright with Chromium (rendering), Pillow (favicon.ico).

Why a browser: it is the renderer every visitor of the site uses, so what you see here is what the
site shows. The PNGs are transparent where the SVG is transparent.

Writes into assets/logo/ and assets/ :
    dhar-logo-on-dark.png / -on-light.png                    2400 px wide (full lockup)
    dhar-wordmark-on-dark.png / -on-light.png                2000 px wide
    dhar-monogram-on-dark.png / -on-light.png                1024 px wide (the D)
    dhar-glyph-on-dark.png                                   512 px wide (ember glyph)
    icon-16/32/48/64/256.png                                 favicon sizes (rounded dark square)
    icon-192.png, icon-512.png                               web-app icons (full bleed, for "maskable")
    apple-touch-icon.png                                     180 px, full bleed (iOS rounds it itself)
    favicon.ico                                              16 + 32 + 48
"""
import base64
import io
import os
import re
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO = os.path.join(ROOT, "assets", "logo")
ASSETS = os.path.join(ROOT, "assets")
CHROMIUM = os.environ.get("CHROMIUM_PATH", "/opt/pw-browsers/chromium")


def aspect(svg_text):
    m = re.search(r'viewBox="([-\d.]+) ([-\d.]+) ([\d.]+) ([\d.]+)"', svg_text)
    return float(m.group(3)) / float(m.group(4))


def render(page, svg_file, out_file, width=None, height=None):
    text = open(svg_file, encoding="utf-8").read()
    a = aspect(text)
    if width and not height:
        height = round(width / a)
    elif height and not width:
        width = round(height * a)
    uri = "data:image/svg+xml;base64," + base64.b64encode(text.encode("utf-8")).decode("ascii")
    page.set_viewport_size({"width": width, "height": height})
    page.set_content('<style>html,body{margin:0;background:transparent}</style>'
                     '<img id="i" src="%s" width="%d" height="%d" style="display:block">' % (uri, width, height))
    page.wait_for_function("document.getElementById('i').complete")
    page.locator("#i").screenshot(path=out_file, omit_background=True)
    return width, height


def main():
    jobs = [
        ("dhar-logo-on-dark.svg", os.path.join(LOGO, "dhar-logo-on-dark.png"), 2400, None),
        ("dhar-logo-on-light.svg", os.path.join(LOGO, "dhar-logo-on-light.png"), 2400, None),
        ("dhar-wordmark-on-dark.svg", os.path.join(LOGO, "dhar-wordmark-on-dark.png"), 2000, None),
        ("dhar-wordmark-on-light.svg", os.path.join(LOGO, "dhar-wordmark-on-light.png"), 2000, None),
        ("dhar-monogram-on-dark.svg", os.path.join(LOGO, "dhar-monogram-on-dark.png"), 1024, None),
        ("dhar-monogram-on-light.svg", os.path.join(LOGO, "dhar-monogram-on-light.png"), 1024, None),
        ("dhar-glyph-on-dark.svg", os.path.join(LOGO, "dhar-glyph-on-dark.png"), 512, None),
        ("icon.svg", os.path.join(LOGO, "icon-16.png"), 16, None),
        ("icon.svg", os.path.join(LOGO, "icon-32.png"), 32, None),
        ("icon.svg", os.path.join(LOGO, "icon-48.png"), 48, None),
        ("icon.svg", os.path.join(LOGO, "icon-64.png"), 64, None),
        ("icon.svg", os.path.join(LOGO, "icon-256.png"), 256, None),
        ("icon-full-bleed.svg", os.path.join(LOGO, "icon-192.png"), 192, None),
        ("icon-full-bleed.svg", os.path.join(LOGO, "icon-512.png"), 512, None),
        ("icon-full-bleed.svg", os.path.join(ASSETS, "apple-touch-icon.png"), 180, None),
    ]
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=CHROMIUM, args=["--no-sandbox"])
        page = browser.new_page(device_scale_factor=1)
        for svg, out, w, h in jobs:
            size = render(page, os.path.join(LOGO, svg), out, w, h)
            print("%-46s %dx%d" % (os.path.relpath(out, ROOT), size[0], size[1]))
        browser.close()

    # favicon.ico: three sizes made from the 256 px render
    base = Image.open(os.path.join(LOGO, "icon-256.png")).convert("RGBA")
    base.save(os.path.join(ASSETS, "favicon.ico"), format="ICO", sizes=[(16, 16), (32, 32), (48, 48)])
    print("assets/favicon.ico  16+32+48")


if __name__ == "__main__":
    sys.exit(main())
