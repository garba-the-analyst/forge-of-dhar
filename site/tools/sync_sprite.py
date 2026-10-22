#!/usr/bin/env python3
"""
sync_sprite.py - copies the generated logo sprite (assets/logo/sprite.inc.html) into index.html,
between the  <!-- sprite:start -->  and  <!-- sprite:end -->  markers.

Run it after tools/build_logo.py:   python3 tools/sync_sprite.py
Why inline: the logo then takes its colours from the page's CSS variables (--logo-ink, --logo-ember,
--logo-tag), which an <img> or an external SVG file cannot do. Exit status 1 if the markers are missing.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = os.path.join(ROOT, "index.html")
SPRITE = os.path.join(ROOT, "assets", "logo", "sprite.inc.html")


def main():
    page = open(PAGE, encoding="utf-8").read()
    sprite = open(SPRITE, encoding="utf-8").read().strip()
    pat = re.compile(r"(<!-- sprite:start -->)(.*?)(<!-- sprite:end -->)", re.S)
    if not pat.search(page):
        print("markers not found in index.html")
        return 1
    new = pat.sub(lambda m: m.group(1) + "\n" + sprite + "\n" + m.group(3), page, count=1)
    if new != page:
        open(PAGE, "w", encoding="utf-8").write(new)
    print("sprite %s (%d bytes)" % ("updated" if new != page else "already current", len(sprite)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
