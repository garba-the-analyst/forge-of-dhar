# Dhar website

A one-page site for the Dhar systems language: the logo, the honest status board, verified code samples,
the bootstrap pipeline, the benchmark, the name. Plain HTML, CSS and JavaScript. No framework, no build step
to view it, no request to any other site.

```
index.html          the page (the logo sprite between the sprite markers is generated)
assets/site.css     styles; the six-colour palette is at the top
assets/site.js      tabs, copy buttons, status filter, speed chart
assets/logo/        logo files          assets/fonts/   fonts (SIL OFL)
assets/brand/       the hero art and the reference banner
docs/BRAND.md       colour, type and logo rules (read before changing any of them)
tools/              build_logo.py, check_logo.py, render_pngs.py, sync_sprite.py, bundle.py
tests/run_tests.py  the site's own tests (palette, logo, samples, speed chart, board, accessibility, widths)
site.webmanifest    install metadata
```

## View it
Serve the folder (`python3 -m http.server`) and open http://localhost:8000. Opening `index.html` straight from a
disk also works, except that browsers refuse to load fonts from `file://`; use the bundle below for that.

## Publish it
This folder lives in `main` as `site/`. GitHub Pages serves a separate generated branch, `website`:

```
make site            # rebuilds the `website` branch locally (refuses if a generated block is stale)
make site PUSH=1     # ...and pushes it
```
`tools/publish_site.sh` (at the repository root) copies the site to the branch root and the community survey, taken
unchanged from the old `gh-pages` branch, to `survey/`. Then, once, in the repository: Settings > Pages > Deploy from a
branch > `website` / root. Link previews use the absolute address in the `og:image` and `og:url` tags; change those two
lines if the address ever changes. **One file**: `python3 tools/bundle.py` writes `dist/dhar.html` with everything inlined
(its survey links point at the absolute `survey/` address).

## Keep the content true
Nothing about status is written by hand in `index.html`. The board, the pipeline, the back-end chips, the progress
timeline, the direction tracks, the dates and the benchmark data are generated from `status/status.json` and
`benchmarks/results/*.json`:

```
python3 status/render.py          # from the repository root; rewrites the generated blocks
python3 tests/test_status.py      # fails if the site, README or progress log has drifted
```
To record a milestone or change a status, edit `status/status.json` and render. The rules are in `docs/HONESTY.md`.
Still by hand, and checked by the site tests: the three code samples (`<code data-sample>` and their result lines; every
sample is compiled with the real `dharc`, run, and compared with what the page shows) and the prose.

```
python3 site/tests/run_tests.py --dharc build/dharc --forge-repo . [--axe axe.min.js]     # from the repository root
```
Needs Python 3, Playwright with Chromium, Pillow, OpenCV, shapely and fontTools (logo tools only), nasm and ld (sample check).

Licence: MIT, copyright 2026 Abdullahi Baba Garba. Fonts: SIL Open Font License.
