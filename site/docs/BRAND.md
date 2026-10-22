# Dhar brand rules

These rules come from the project owner and are fixed.

## 1. Colour: six colours, final

Dhar Design System v1.0. No other colour is used anywhere: not on the page, not in the logo files.

| Name | Hex | Meaning | Used for |
| --- | --- | --- | --- |
| Forge Black | `#0B0B0D` | depth, strength, foundation | page ground, text on Ember |
| Molten Ember | `#FF5C00` | energy, intensity, drive | primary action, structure keywords, the logo's rule and glyph |
| Tempered Steel | `#4B5563` | stability, resilience, trust | outlines, chart bars, markers |
| Precision Cyan | `#22D3EE` | clarity, accuracy, focus | links, focus ring, data and machine words in code, "works" |
| Hot Copper | `#C2410C` | heat, performance, craft | the end of the heat gradient, light-ground logo accent |
| Ash | `#F3F4F6` | balance, refinement, purpose | headings, code, the lettering |

Softer tones are made from these with `color-mix()` or opacity (see `--panel`, `--hair`, `--fg-2`, `--fg-3`
in `assets/site.css`). `tests/run_tests.py` fails if any other 6-digit hex colour appears in the page, the
stylesheet, the script, the manifest or any logo file.

There is one look: dark, on Forge Black. The palette has no light ground for Dhar, so the site has no light theme.
The logo files include an on-light version (Forge Black letters, Hot Copper accent) for print and white documents.

## 2. Type

* **Saira** (variable, weight and width axes): headings and text. It is the face of the tagline in the hero banner.
* **JetBrains Mono** (variable): code, data, labels. It is the face in the code screenshots.
* **Noto Naskh Arabic Bold**: the single Arabic word *dahr* on the page.

All three are under the SIL Open Font License and ship in `assets/fonts/` (no request to any other site).

## 3. Logo

The lockup is the DHAR lettering of the hero banner, traced from it: stencil-cut D, split-bar A, chamfered R,
an ember rule with the small centre glyph, and the tagline "Bare Metal. Absolute Control."

* The letters are polygons stored as numbers in `tools/build_logo.py` (units = banner pixels). The tagline is
  Saira Medium turned into outlines, so the files need no font.
* `python3 tools/check_logo.py` measures the overlap with `assets/brand/reference-banner.jpg`
  (D .981, H .983, A .977, R .978, all letters .980, glyph .927).
* The logo files are flat colour. The stone texture on the page's hero is a browser effect (SVG filter
  `#stone` in `index.html`), not part of the logo files.
* Keep clear space around the lockup of at least the height of the D's bar; do not stretch, recolour or outline it.

Files in `assets/logo/` (SVG are the masters; PNG are renders):

| File | Use |
| --- | --- |
| `dhar-logo-on-dark.svg/.png`, `-on-light`, `-mono-white`, `-mono-black` | full lockup |
| `dhar-wordmark-*` | the four letters only |
| `dhar-monogram-*` | the D alone |
| `dhar-glyph-*` | the ember glyph alone |
| `icon.svg`, `icon-16..256.png`, `icon-192/512.png`, `../apple-touch-icon.png`, `../favicon.ico` | app and tab icons |
| `sprite.inc.html` | inline sprite the page uses so the logo follows the CSS colours |
| `logo-spec.json` | the geometry as data |

Regenerate after any change: `python3 tools/build_logo.py && python3 tools/check_logo.py && python3 tools/render_pngs.py && python3 tools/sync_sprite.py`.
