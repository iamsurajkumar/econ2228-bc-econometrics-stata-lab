#!/usr/bin/env bash
# Build the GitHub Pages site into _site/:
#   - site/index.html (the course page)
#   - lectures/ (slides, do-files, data served as plain files)
#   - notebooks/<week>/<name>/ : every marimo notebook exported to run in the browser (WASM)
# Runs in GitHub Actions on every push; run it locally to preview:
#   scripts/build_site.sh && python3 -m http.server --directory _site 8000
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"
rm -rf _site && mkdir -p _site
cp -R site/. _site/
cp -R lectures _site/lectures

for nb in lectures/week-*/*.py; do
  grep -q "^import marimo" "$nb" || continue
  week="$(basename "$(dirname "$nb")")"
  name="$(basename "$nb" .py)"
  out="_site/notebooks/$week/$name"
  echo "Exporting $nb -> $out"
  uv run --with marimo marimo export html-wasm "$nb" -o "$out" --mode run
  # Data the notebook reads through mo.notebook_location(): CSVs next to it and public/.
  find "$(dirname "$nb")" -maxdepth 1 -name '*.csv' -exec cp {} "$out/" \;
  [ -d "$(dirname "$nb")/public" ] && cp -R "$(dirname "$nb")/public" "$out/"
  rm -f "$out/CLAUDE.md"
done
touch _site/.nojekyll
echo "Site built in _site/"
