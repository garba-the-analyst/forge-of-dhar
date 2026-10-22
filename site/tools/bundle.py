#!/usr/bin/env python3
"""
bundle.py - turns the multi-file site into ONE self-contained HTML file (CSS, JavaScript, fonts and
images all inlined as text or data: URIs). Handy for sending the page by email, opening it from a
disk, or uploading it to a host that takes a single file.

    python3 tools/bundle.py                      ->  dist/dhar.html   (complete document)
    python3 tools/bundle.py --artifact -o x.html ->  a fragment (no <html>/<head>/<body>) for hosts that
                                                    wrap the page themselves
Nothing is minified or altered apart from the inlining, and no colour or font is changed.
"""
import argparse
import base64
import mimetypes
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
mimetypes.add_type("font/woff2", ".woff2")


def uri(path):
    full = os.path.join(ROOT, path)
    mime = mimetypes.guess_type(full)[0] or "application/octet-stream"
    with open(full, "rb") as f:
        return "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifact", action="store_true", help="emit a fragment instead of a document")
    ap.add_argument("-o", "--out", default=os.path.join(ROOT, "dist", "dhar.html"))
    ap.add_argument("--survey-url", default="https://garba-the-analyst.github.io/forge-of-dhar/survey/",
                    help="where the survey links point in a single-file build (the site itself uses the relative link survey/)")
    a = ap.parse_args()

    page = read("index.html")

    # 1. stylesheet, with its fonts inlined
    css = read("assets/site.css")
    css = re.sub(r'url\("(fonts/[^"]+)"\)', lambda m: 'url("%s")' % uri("assets/" + m.group(1)), css)
    page = re.sub(r'<link rel="stylesheet" href="assets/site.css">', lambda m: "<style>\n%s\n</style>" % css, page)

    # 2. script
    js = read("assets/site.js")
    page = page.replace('<script src="assets/site.js"></script>', "<script>\n%s\n</script>" % js)

    # 3. images and icons
    page = page.replace('src="assets/brand/hero-pour.jpg"', 'src="%s"' % uri("assets/brand/hero-pour.jpg"))
    page = page.replace('href="assets/logo/icon.svg"', 'href="%s"' % uri("assets/logo/icon.svg"))
    page = page.replace('href="assets/apple-touch-icon.png"', 'href="%s"' % uri("assets/apple-touch-icon.png"))

    # 4. the site links to the survey as survey/ (it lives under the same Pages root); a single file has no root
    page = page.replace('href="survey/"', 'href="%s"' % a.survey_url)

    # 5. drop what cannot work from one file
    page = re.sub(r'<link rel="preload"[^>]*>\n?', "", page)
    page = re.sub(r'<link rel="icon" href="assets/favicon.ico"[^>]*>\n?', "", page)
    page = re.sub(r'<link rel="manifest"[^>]*>\n?', "", page)
    page = re.sub(r'<meta property="og:image"[^>]*>\n?', "", page)

    if a.artifact:
        title = re.search(r"<title>.*?</title>", page).group(0)
        style = re.search(r"<style>.*?</style>", page, re.S).group(0)
        body = re.search(r"<body>(.*)</body>", page, re.S).group(1)
        page = (title + '\n<meta name="claude:viewport-fit-sides" content="cover">\n'
                + style + "\n" + body.strip() + "\n")

    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(page)
    print("%s  %.0f KB" % (os.path.relpath(a.out, ROOT), len(page.encode("utf-8")) / 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
