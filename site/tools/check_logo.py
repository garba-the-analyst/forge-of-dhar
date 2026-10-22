#!/usr/bin/env python3
"""
check_logo.py - measures how closely the vector logo matches the reference banner.

"Exactly like the banner" is checkable: this script rasterises the letter outlines in
tools/build_logo.py at 4x the banner's resolution, thresholds the banner's lettering the same way
the banner tracing did, and reports the overlap (intersection over union) letter by letter.
It also draws a red/green difference image so any deviation can be seen.

    python3 tools/check_logo.py [--out diff.png]

Exit status is 1 when any letter falls below MIN_IOU, so it can run in CI or in tests/run_tests.py.

Reading the numbers: the banner is a JPEG of stone-textured lettering, so its own edges wobble by
about half a pixel; an overlap of 0.97 or more means the outlines agree to within that wobble.
Needs: numpy, opencv-python (cv2)
"""
import argparse
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_logo as B  # noqa: E402

ROOT = B.ROOT
REF = os.path.join(ROOT, "assets", "brand", "reference-banner.jpg")
MIN_IOU = 0.965
S = 4


def raster(rings, holes, shape, origin):
    """Fill polygons (banner coordinates) into a mask at scale S, relative to origin."""
    m = np.zeros(shape, np.uint8)
    for r in rings:
        pts = np.array([[(x - origin[0]) * S, (y - origin[1]) * S] for x, y in r], np.int32)
        cv2.fillPoly(m, [pts], 255)
    for h in holes:
        pts = np.array([[(x - origin[0]) * S, (y - origin[1]) * S] for x, y in h], np.int32)
        cv2.fillPoly(m, [pts], 0)
    return m


def iou(a, b):
    inter = np.logical_and(a > 0, b > 0).sum()
    union = np.logical_or(a > 0, b > 0).sum()
    return inter / float(union) if union else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="write a difference image here")
    args = ap.parse_args()

    im = cv2.imread(REF)
    if im is None:
        print("cannot read", REF)
        return 2

    cx, cy = B.BANNER_CROP
    x0, y0, x1, y1 = cx, cy, cx + 700, cy + 180
    crop = im[y0:y1, x0:x1]
    big = cv2.resize(crop, None, fx=S, fy=S, interpolation=cv2.INTER_CUBIC)
    g = cv2.GaussianBlur(cv2.cvtColor(big, cv2.COLOR_BGR2GRAY), (0, 0), 3)
    _, ref = cv2.threshold(g, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    ref = cv2.morphologyEx(cv2.morphologyEx(ref, cv2.MORPH_CLOSE, k), cv2.MORPH_OPEN, k)

    # vector side, in crop coordinates (the numbers in build_logo.LETTERS)
    mine = np.zeros_like(ref)
    letter_x = {"D": (0, 175), "H": (185, 345), "A": (345, 535), "R": (535, 700)}
    results, ok = {}, True
    for ch, (xa, xb) in letter_x.items():
        m = raster(B.LETTERS[ch], B.HOLES.get(ch, []), ref.shape, (0, 0))
        mine = np.maximum(mine, m)
        window = np.zeros_like(ref)
        window[:, xa * S:xb * S] = 255
        r_win = cv2.bitwise_and(ref, window)
        v = iou(m, r_win)
        results[ch] = v
        ok &= v >= MIN_IOU

    total = iou(mine, ref)
    ok &= total >= MIN_IOU
    for ch, v in results.items():
        print("%s  overlap %.4f %s" % (ch, v, "ok" if v >= MIN_IOU else "BELOW %.3f" % MIN_IOU))
    print("all letters  overlap %.4f %s" % (total, "ok" if total >= MIN_IOU else "BELOW %.3f" % MIN_IOU))

    # glyph against the ember pixels of the banner (compared before centring: banner coordinates)
    b, gch, r = [im[:, :, i].astype(int) for i in (0, 1, 2)]
    orange = ((r > 150) & (r - b > 90) & (gch > 40) & (gch < 150)).astype(np.uint8) * 255
    gx0, gy0, gx1, gy1 = 685, 452, 745, 506
    sub = orange[gy0:gy1, gx0:gx1]
    gbig = cv2.resize(sub, None, fx=8, fy=8, interpolation=cv2.INTER_CUBIC)
    gbig = cv2.GaussianBlur(gbig, (0, 0), 4)
    _, gbig = cv2.threshold(gbig, 100, 255, cv2.THRESH_BINARY)
    gm = np.zeros_like(gbig)
    for ring in B.GLYPH_ABS:
        pts = np.array([[(x - gx0) * 8, (y - gy0) * 8] for x, y in ring], np.int32)
        cv2.fillPoly(gm, [pts], 255)
    gv = iou(gm, gbig)
    print("glyph        overlap %.4f %s" % (gv, "ok" if gv >= 0.90 else "BELOW 0.90"))
    ok &= gv >= 0.90

    if args.out:
        rgb = np.zeros(ref.shape + (3,), np.uint8)
        rgb[(ref > 0) & (mine > 0)] = (190, 190, 190)       # agree: grey
        rgb[(ref > 0) & (mine == 0)] = (60, 60, 255)         # banner only: red (BGR)
        rgb[(ref == 0) & (mine > 0)] = (80, 220, 80)         # vector only: green
        cv2.imwrite(args.out, cv2.resize(rgb, None, fx=0.5, fy=0.5, interpolation=cv2.INTER_AREA))
        print("difference image:", args.out, "(grey = agree, red = banner only, green = vector only)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
