#!/usr/bin/env bash
# publish_site.sh - builds the `website` branch that GitHub Pages serves.
#
#   tools/publish_site.sh           build or update the local `website` branch
#   tools/publish_site.sh --push    ...and push it to origin
#
# The branch holds only what a visitor needs: the site (index.html, assets/, site.webmanifest) at the root and the
# community survey under survey/. It has no compiler source, tests or tools. It is rebuilt from `main` each time, as
# a new commit on top of the previous one, so the branch history is a log of what was published.
#
# It refuses to run while any generated block (status board, README, progress log) is out of date.
#
# Settings -> Pages -> "Deploy from a branch" -> branch `website`, folder `/ (root)`.
# The survey comes from the old gh-pages branch (SURVEY_REF); it is copied as it stands and is not edited.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

BRANCH="${BRANCH:-website}"
SURVEY_REF="${SURVEY_REF:-origin/gh-pages}"
PUSH=0; [ "${1:-}" = "--push" ] && PUSH=1

python3 status/render.py --check >/dev/null || { echo "Generated blocks are out of date. Run: python3 status/render.py" >&2; exit 1; }
git rev-parse --verify -q "$SURVEY_REF" >/dev/null || { echo "Survey source $SURVEY_REF not found. Run: git fetch origin gh-pages" >&2; exit 1; }

OUT="$(mktemp -d)"; IDX="$(mktemp -u)"
trap 'rm -rf "$OUT" "$IDX"' EXIT

# 1. the site
cp site/index.html site/site.webmanifest "$OUT/"
mkdir -p "$OUT/assets"
tar -C site/assets --exclude=./brand/reference-banner.jpg -cf - . | tar -C "$OUT/assets" -xf -
touch "$OUT/.nojekyll"

# 2. the survey, exactly as published on the old branch (only the parts a visitor loads)
mkdir -p "$OUT/survey"
git archive "$SURVEY_REF" index.html assets relay relay-check.html LICENSE | tar -x -C "$OUT/survey"

# 3. a note for anyone who lands on the branch
cat > "$OUT/README.md" <<EON
# Dhar website (generated)

This branch is built by \`tools/publish_site.sh\` from the \`main\` branch of this repository. Do not edit it by hand: the
next publish replaces everything. The source is in \`site/\` on \`main\`; the survey under \`survey/\` is copied from the
\`gh-pages\` branch.

Built from \`main\` at $(git rev-parse --short HEAD) on $(date -u +%Y-%m-%d).
EON

# 4. commit it with plumbing, so no checkout is disturbed
export GIT_INDEX_FILE="$IDX"
git --work-tree="$OUT" add -A -f .
TREE="$(git write-tree)"
unset GIT_INDEX_FILE
PARENT=""
for ref in "refs/heads/$BRANCH" "refs/remotes/origin/$BRANCH"; do
  if git rev-parse --verify -q "$ref" >/dev/null; then PARENT="$(git rev-parse "$ref")"; break; fi
done
if [ -n "$PARENT" ] && [ "$(git rev-parse "$PARENT^{tree}")" = "$TREE" ]; then
  echo "website branch already up to date ($PARENT)"; COMMIT="$PARENT"
else
  MSG="Publish site from main@$(git rev-parse --short HEAD)"
  COMMIT="$(git commit-tree "$TREE" ${PARENT:+-p "$PARENT"} -m "$MSG")"
  git update-ref "refs/heads/$BRANCH" "$COMMIT"
  echo "built $BRANCH at $COMMIT"
fi
git ls-tree -r --name-only "$BRANCH" | sed -n '1,400p' | awk -F/ '{print $1 (NF>1?"/":"")}' | sort | uniq -c | sed 's/^/  /'
if [ "$PUSH" = 1 ]; then git push origin "$BRANCH"; fi
