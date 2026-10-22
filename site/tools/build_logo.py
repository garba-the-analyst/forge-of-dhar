#!/usr/bin/env python3
"""
build_logo.py - generates every Dhar logo file from one set of coordinates.

THE LOGO
    The Dhar logo is the lockup in the project owner's hero banner (assets/brand/reference-banner.jpg):

        D H A R                     heavy, wide, straight-cut letters. The D is split by a stencil slit
        ---------- glyph ----------  and a diagonal cut, the A is split by a diagonal channel, the R has
        Bare Metal. Absolute Control. a chamfered bowl. No curves anywhere: it is cut, not drawn.

    The letter outlines were TRACED from that banner (tools/trace_reference.py prints the raw
    coordinates) and then cleaned to straight edges. The cleaned numbers are in LETTERS, GLYPH and
    LAYOUT below. tools/check_logo.py compares the result to the banner pixel by pixel.

    What was cleaned, and what was deliberately kept:
      * kept     every letter shape, cut and proportion of the banner (it is the reference)
      * cleaned  stone texture, JPEG blur, 0.5 px wobble in the edges; the line either side of the
                 glyph is now symmetric and the glyph sits exactly on the centre line (in the banner
                 it is about 15 px left of centre)
      * flat     colours: the files are flat; the stone texture of the banner is a website effect
                 (see assets/site.css, .stone), not part of the logo files

COORDINATES
    Units are pixels of the reference banner (1168 x 784). All numbers below are measured there,
    in "crop" coordinates: x from 380, y from 270. build() subtracts ORIGIN so the logo starts at 0,0.

OUTPUT (assets/logo/)
    dhar-logo-<colourway>.svg        the full lockup
    dhar-wordmark-<colourway>.svg    DHAR only
    dhar-monogram-<colourway>.svg    the D only
    dhar-glyph-<colourway>.svg       the small ember glyph only
    icon.svg, icon-full-bleed.svg    favicon / app icon (monogram on Forge Black)
    sprite.inc.html                  inline <symbol>s for the website
    logo-spec.json                   the numbers and colours used
    colourways: on-dark, on-light, mono-white, mono-black.  All text is outlined: no fonts needed.

Usage:   python3 tools/build_logo.py            (from the site root; then tools/render_pngs.py)
Needs:   shapely, fontTools (+ brotli for woff2)
"""
import io
import json
import os

from shapely.geometry import Polygon
from shapely.ops import unary_union

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "logo")

# --------------------------------------------------------------------------------------------
# Colours: the Dhar design system v1.0 palette, fixed and final. These six are the ONLY colours in
# every logo file. (Where a softer tone is wanted, a file uses one of them at reduced opacity.)
# --------------------------------------------------------------------------------------------
FORGE_BLACK = "#0B0B0D"
MOLTEN_EMBER = "#FF5C00"
TEMPERED_STEEL = "#4B5563"
PRECISION_CYAN = "#22D3EE"
HOT_COPPER = "#C2410C"
ASH = "#F3F4F6"

# --------------------------------------------------------------------------------------------
# Letter outlines (crop coordinates of the reference banner). Each polygon is a list of (x, y);
# R also has a hole. Order does not matter; the cap line is y = 13 and the baseline y = 170.
# --------------------------------------------------------------------------------------------
ORIGIN = (7.6, 13.0)       # top-left of the D = (0, 0) in the logo

LETTERS = {
    # D: the main body is a "C-reversed" bar (top bar, bowl, bottom bar). A detached block makes the
    # lower left of the stem; a horizontal slit and a 45-degree diagonal cut separate it.
    "D": [
        [(7.6, 13), (133, 13), (166.5, 46.5), (166.5, 136.5), (133, 170), (24.2, 170), (54.8, 137),
         (116.8, 137), (131.5, 122.3), (131.5, 61.3), (117.0, 46.8), (7.6, 46.8)],
        [(7.6, 63.7), (44.4, 63.7), (44.4, 131.5), (7.6, 166.4)],
    ],
    # H: two stems and a bar, nothing else.
    "H": [
        [(190.6, 13), (226.8, 13), (226.8, 74.8), (300.6, 74.8), (300.6, 13), (336.8, 13), (336.8, 170),
         (300.6, 170), (300.6, 107.6), (226.8, 107.6), (226.8, 170), (190.6, 170)],
    ],
    # A: flat apex; a triangular counter that opens into a diagonal channel on the left, so the
    # crossbar belongs to the right leg; a notch under the crossbar.
    "A": [
        [(453.0, 13), (424.5, 13), (351.8, 170), (389.8, 170), (438.8, 66.0), (470.0, 129.3),
         (427.8, 129.3), (413.0, 159.5), (484.2, 159.5), (491.2, 170), (527.8, 170)],
    ],
    # R: stem, chamfered bowl with a rectangular counter (the hole), straight diagonal leg.
    "R": [
        [(538.8, 13), (654.2, 13), (684, 43), (684, 91.5), (659, 116.5), (648, 118), (689.8, 170),
         (645.5, 170), (576.6, 90.8), (576.6, 170), (538.8, 170)],
    ],
}
HOLES = {
    "R": [[(576.6, 46.8), (638.2, 46.8), (648, 56.2), (648, 80.8), (640.2, 84), (576.6, 84)]],
}

# The small glyph between the two lines: two shards. Absolute banner coordinates (not crop).
GLYPH_ABS = [
    [(710.1, 457.1), (709.7, 488.8), (708.2, 489.6), (696.4, 477.8), (696.8, 469.1), (691.0, 475.2),
     (691.0, 479.4), (707.2, 495.9), (713.8, 500.8), (714.0, 459.5)],
    [(736.7, 469.0), (724.0, 469.1), (724.1, 473.0), (731.8, 473.4), (731.9, 480.0), (719.0, 493.2),
     (718.0, 495.5), (719.0, 498.6), (736.9, 481.6)],
]
GLYPH_ABS_CENTRE_X = 714.0
BANNER_CROP = (380, 270)

# Lockup layout, in logo units (0,0 = top-left of the D).
LAYOUT = dict(
    cap=157.0,               # cap height (170 - 13)
    rule_y=194.5,            # y of the ember rule (banner row 477)
    rule_w=1.6,              # rule thickness
    rule_gap=12.0,           # clear space between rule and glyph
    glyph_y0=174.1,          # top of the glyph (banner y 457.1 - 283)
    tag_cap=21.0,            # tagline cap height
    tag_baseline=257.0,      # tagline baseline
    tag_width=567.0,         # tagline ink width (banner: x 444 to 1011)
    tag_font="saira-latin-500-normal.woff2",   # in tools/fonts/ (Saira Medium, SIL OFL)
    tag_split="Bare Metal.",
    tag_text="Bare Metal. Absolute Control.",
    pad=14.0,                # clear space baked into the lockup file
)

COLOURWAYS = {
    # tag_opacity softens "Bare Metal." the way the banner does; the ember half stays full strength
    "on-dark":    dict(ink=ASH,         ember=MOLTEN_EMBER, tag=ASH,            tag_opacity=0.72),
    "on-light":   dict(ink=FORGE_BLACK, ember=HOT_COPPER,   tag=TEMPERED_STEEL, tag_opacity=1.0),
    "mono-white": dict(ink=ASH,         ember=ASH,          tag=ASH,            tag_opacity=1.0),
    "mono-black": dict(ink=FORGE_BLACK, ember=FORGE_BLACK,  tag=FORGE_BLACK,    tag_opacity=1.0),
}


# --------------------------------------------------------------------------------------------
# Geometry
# --------------------------------------------------------------------------------------------
def local(pt):
    return (pt[0] - ORIGIN[0], pt[1] - ORIGIN[1])


def letter_geometry(ch):
    """Shapely geometry of one letter in logo coordinates (holes cut out)."""
    parts = [Polygon([local(p) for p in ring], [[local(p) for p in h] for h in HOLES.get(ch, [])]) if i == 0
             else Polygon([local(p) for p in ring]) for i, ring in enumerate(LETTERS[ch])]
    g = unary_union(parts) if len(parts) > 1 else parts[0]
    assert g.is_valid, "letter %s is not a valid shape" % ch
    return g


def wordmark_geometry():
    g = unary_union([letter_geometry(c) for c in "DHAR"])
    return g


def build_glyph(centre_x):
    """Return glyph polygons in logo coordinates, centred on centre_x."""
    out = []
    for ring in GLYPH_ABS:
        pts = [(x - BANNER_CROP[0] - ORIGIN[0], y - BANNER_CROP[1] - ORIGIN[1]) for x, y in ring]
        out.append(pts)
    gx = GLYPH_ABS_CENTRE_X - BANNER_CROP[0] - ORIGIN[0]
    return [[(x + (centre_x - gx), y) for x, y in ring] for ring in out]


# --------------------------------------------------------------------------------------------
# Tagline from the font (outlined)
# --------------------------------------------------------------------------------------------
def tagline_paths(centre_x):
    """Outline the tagline. Returns (grey_path_d, ember_path_d, tracking_em, x_left, x_right)."""
    from fontTools.ttLib import TTFont
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen

    L = LAYOUT
    font = TTFont(os.path.join(ROOT, "tools", "fonts", L["tag_font"]))
    gs, cmap, hmtx = font.getGlyphSet(), font.getBestCmap(), font["hmtx"]
    cap_units = font["OS/2"].sCapHeight
    s = L["tag_cap"] / cap_units
    text = L["tag_text"]
    names = [cmap[ord(c)] for c in text]
    adv = [hmtx[n][0] * s for n in names]

    # ink extents of first and last glyph so that the ink (not the advance) spans tag_width
    def lsb(n):
        return hmtx[n][1] * s

    def ink_right(n, a):
        from fontTools.pens.boundsPen import BoundsPen
        bp = BoundsPen(gs); gs[n].draw(bp)
        return (bp.bounds[2] * s) if bp.bounds else a
    first_lsb = lsb(names[0])
    last_ink_right = ink_right(names[-1], adv[-1])
    n_gaps = len(text) - 1
    track = (L["tag_width"] - (sum(adv[:-1]) + last_ink_right - first_lsb)) / n_gaps

    x0 = centre_x - L["tag_width"] / 2.0 - first_lsb
    x, grey, ember = x0, [], []
    split = len(L["tag_split"])
    for i, (ch, n, a) in enumerate(zip(text, names, adv)):
        pen = SVGPathPen(gs, ntos=lambda v: ("%.2f" % v).rstrip("0").rstrip("."))
        gs[n].draw(TransformPen(pen, (s, 0, 0, -s, x, L["tag_baseline"])))
        d = pen.getCommands()
        if d:
            (grey if i < split else ember).append(d)
        x += a + track
    return " ".join(grey), " ".join(ember), track / L["tag_cap"]


# --------------------------------------------------------------------------------------------
# SVG output
# --------------------------------------------------------------------------------------------
def fmt(v):
    s = "%.2f" % v
    return s.rstrip("0").rstrip(".") if "." in s else s


def ring_d(coords):
    pts = list(coords)
    if pts[0] == pts[-1]:
        pts = pts[:-1]
    return "M" + "L".join("%s %s" % (fmt(x), fmt(y)) for x, y in pts) + "Z"


def path_d(geom):
    polys = [geom] if geom.geom_type == "Polygon" else list(geom.geoms)
    d = []
    for p in polys:
        d.append(ring_d(p.exterior.coords))
        for h in p.interiors:
            d.append(ring_d(h.coords))
    return "".join(d)


def polys_d(rings):
    return "".join(ring_d(r) for r in rings)


def svg_doc(inner, vb, title, bg=None, radius=None):
    x, y, w, h = vb
    back = ""
    if bg:
        back = '<rect x="%s" y="%s" width="%s" height="%s"%s fill="%s"/>' % (
            fmt(x), fmt(y), fmt(w), fmt(h), (' rx="%s"' % fmt(radius)) if radius else "", bg)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" width="%s" height="%s" '
            'role="img" aria-label="%s"><title>%s</title>%s%s</svg>\n') % (
        fmt(x), fmt(y), fmt(w), fmt(h), fmt(w), fmt(h), title, title, back, inner)


def fill_path(d, fill, extra=""):
    return '<path d="%s" fill="%s" fill-rule="evenodd"%s/>' % (d, fill, extra)


def build():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):                       # generated folder: start clean so no stale files survive
        os.remove(os.path.join(OUT, f))

    L = LAYOUT
    word = wordmark_geometry()
    wx0, wy0, wx1, wy1 = word.bounds
    W = wx1 - wx0                                   # wordmark width (about 682)
    assert abs(wx0) < 0.01 and abs(wy0) < 0.01, "wordmark must start at 0,0, starts at %s,%s" % (wx0, wy0)
    cx = W / 2.0

    glyph = build_glyph(cx)
    gxs = [x for r in glyph for x, _ in r]
    g_left, g_right = min(gxs), max(gxs)
    gys = [y for r in glyph for _, y in r]
    g_top, g_bot = min(gys), max(gys)
    left_rule = (0.0, g_left - L["rule_gap"])
    right_rule = (g_right + L["rule_gap"], W)
    grey_d, ember_d, track_em = tagline_paths(cx)

    word_d = path_d(word)
    D_geom = letter_geometry("D")
    dx0, dy0, dx1, dy1 = D_geom.bounds
    glyph_d = polys_d(glyph)

    def rule_rects(c):
        y0 = L["rule_y"] - L["rule_w"] / 2.0
        return ('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (fmt(left_rule[0]), fmt(y0), fmt(left_rule[1] - left_rule[0]), fmt(L["rule_w"]), c) +
                '<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (fmt(right_rule[0]), fmt(y0), fmt(right_rule[1] - right_rule[0]), fmt(L["rule_w"]), c))

    files = {}
    pad = L["pad"]
    total_h = L["tag_baseline"] + 3   # a hair below the baseline for the full stops
    for cw, c in COLOURWAYS.items():
        # full lockup
        inner = (fill_path(word_d, c["ink"]) + rule_rects(c["ember"]) + fill_path(glyph_d, c["ember"]) +
                 fill_path(grey_d, c["tag"], (' fill-opacity="%s"' % c["tag_opacity"]) if c["tag_opacity"] < 1 else "") + fill_path(ember_d, c["ember"]))
        files["dhar-logo-%s.svg" % cw] = svg_doc(inner, (-pad, -pad, W + 2 * pad, total_h + 2 * pad), "Dhar. Bare Metal. Absolute Control.")
        # wordmark
        files["dhar-wordmark-%s.svg" % cw] = svg_doc(fill_path(word_d, c["ink"]), (-8, -8, W + 16, L["cap"] + 16), "Dhar")
        # monogram (the D)
        files["dhar-monogram-%s.svg" % cw] = svg_doc(fill_path(path_d(D_geom), c["ink"]), (-8, -8, dx1 + 16, L["cap"] + 16), "Dhar monogram")
        # glyph
        gw, gh = g_right - g_left, g_bot - g_top
        files["dhar-glyph-%s.svg" % cw] = svg_doc(fill_path(glyph_d, c["ember"]), (g_left - 6, g_top - 6, gw + 12, gh + 12), "Dhar glyph")

    # icon: the D on Forge Black. 64-unit square, D centred and scaled to 40 units wide.
    k = 40.0 / (dx1 - dx0)
    ox = 32 - (dx1 + dx0) / 2.0 * k
    oy = 32 - (dy1 + dy0) / 2.0 * k
    icon_inner = '<g transform="translate(%s %s) scale(%s)">%s</g>' % (fmt(ox), fmt(oy), ("%.5f" % k), fill_path(path_d(D_geom), ASH))
    files["icon.svg"] = svg_doc(icon_inner, (0, 0, 64, 64), "Dhar", bg=FORGE_BLACK, radius=12)
    k2 = 40.0 / (dx1 - dx0) * 0.78
    ox2 = 45 - (dx1 + dx0) / 2.0 * k2
    oy2 = 45 - (dy1 + dy0) / 2.0 * k2
    files["icon-full-bleed.svg"] = svg_doc('<g transform="translate(%s %s) scale(%s)">%s</g>' % (fmt(ox2), fmt(oy2), ("%.5f" % k2), fill_path(path_d(D_geom), ASH)),
                                           (0, 0, 90, 90), "Dhar", bg=FORGE_BLACK)

    for name, text in files.items():
        with io.open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            f.write(text)

    # inline sprite for the website: colours come from CSS variables so the logo follows the theme
    ink = 'style="fill:var(--logo-ink)"'
    emb = 'style="fill:var(--logo-ember)"'
    tag = 'style="fill:var(--logo-tag);fill-opacity:var(--logo-tag-opacity,1)"'
    y0 = L["rule_y"] - L["rule_w"] / 2.0
    word_el = '<path d="%s" fill-rule="evenodd" %s/>' % (word_d, ink)
    rest = ('<rect x="%s" y="%s" width="%s" height="%s" %s/>' % (fmt(left_rule[0]), fmt(y0), fmt(left_rule[1]), fmt(L["rule_w"]), emb) +
            '<rect x="%s" y="%s" width="%s" height="%s" %s/>' % (fmt(right_rule[0]), fmt(y0), fmt(right_rule[1] - right_rule[0]), fmt(L["rule_w"]), emb) +
            '<path d="%s" %s/>' % (glyph_d, emb) + '<path d="%s" %s/>' % (grey_d, tag) + '<path d="%s" %s/>' % (ember_d, emb))
    full = word_el + rest
    lockup_vb = '%s %s %s %s' % (fmt(-pad), fmt(-pad), fmt(W + 2 * pad), fmt(total_h + 2 * pad))
    sprite = "".join([
        '<symbol id="dhar-logo" viewBox="%s">%s</symbol>' % (lockup_vb, full),
        # the lockup split in two (same viewBox) so the website can texture the lettering alone
        '<symbol id="dhar-lockup-word" viewBox="%s">%s</symbol>' % (lockup_vb, word_el),
        '<symbol id="dhar-lockup-rest" viewBox="%s">%s</symbol>' % (lockup_vb, rest),
        '<symbol id="dhar-wordmark" viewBox="-8 -8 %s %s"><path d="%s" fill-rule="evenodd" %s/></symbol>' % (fmt(W + 16), fmt(L["cap"] + 16), word_d, ink),
        '<symbol id="dhar-monogram" viewBox="-8 -8 %s %s"><path d="%s" fill-rule="evenodd" %s/></symbol>' % (fmt(dx1 + 16), fmt(L["cap"] + 16), path_d(D_geom), ink),
        '<symbol id="dhar-glyph" viewBox="%s %s %s %s"><path d="%s" %s/></symbol>' % (fmt(g_left - 6), fmt(g_top - 6), fmt(g_right - g_left + 12), fmt(g_bot - g_top + 12), glyph_d, emb),
    ])
    with io.open(os.path.join(OUT, "sprite.inc.html"), "w", encoding="utf-8") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0" style="position:absolute" aria-hidden="true" focusable="false">%s</svg>\n' % sprite)

    spec = dict(
        source="assets/brand/reference-banner.jpg (crop origin %s,%s; logo origin %s,%s)" % (BANNER_CROP[0], BANNER_CROP[1], ORIGIN[0], ORIGIN[1]),
        units="pixels of the reference banner; the lockup is %s x %s units" % (fmt(W), fmt(total_h)),
        wordmark_width=round(W, 2), cap_height=L["cap"], layout=L, tagline_tracking_em=round(track_em, 3),
        palette=dict(forge_black=FORGE_BLACK, molten_ember=MOLTEN_EMBER, tempered_steel=TEMPERED_STEEL,
                     precision_cyan=PRECISION_CYAN, hot_copper=HOT_COPPER, ash=ASH),
        letters={k: v for k, v in LETTERS.items()}, holes=HOLES, glyph_banner_coords=GLYPH_ABS,
        files=sorted(files) + ["sprite.inc.html", "logo-spec.json"])
    with io.open(os.path.join(OUT, "logo-spec.json"), "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=1)
    print("wrote %d SVG files + sprite + spec to %s" % (len(files), OUT))
    return dict(W=W, total_h=total_h, track_em=track_em)


if __name__ == "__main__":
    info = build()
    print("lockup %.1f x %.1f units, tagline tracking %.3f em" % (info["W"], info["total_h"], info["track_em"]))
