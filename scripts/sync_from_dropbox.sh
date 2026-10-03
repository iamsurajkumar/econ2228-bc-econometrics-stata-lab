#!/usr/bin/env bash
# Copy the student-facing files listed in scripts/publish_list.txt from the Dropbox
# lectures/ folder into lectures/. Works on the Mac and on omabox (Linux).
#   Usage: scripts/sync_from_dropbox.sh            (then: git add -A && git commit && git push)
#   Override the source:  LECTURES=/path/to/lectures scripts/sync_from_dropbox.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "${LECTURES:-}" ]; then
  for c in "$HOME/Library/CloudStorage/Dropbox/PhD/teaching/econometrics/lectures" \
           "$HOME/Dropbox/PhD/teaching/econometrics/lectures"; do
    [ -d "$c" ] && LECTURES="$c" && break
  done
fi
[ -d "${LECTURES:-}" ] || { echo "Cannot find the Dropbox lectures folder; set LECTURES=..."; exit 1; }
echo "Source: $LECTURES"

missing=0
while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs)"
  [ -z "$line" ] && continue
  if [ -f "$LECTURES/$line" ]; then
    mkdir -p "$REPO/lectures/$(dirname "$line")"
    cp -p "$LECTURES/$line" "$REPO/lectures/$line"
  else
    echo "MISSING: $line"; missing=1
  fi
done < "$REPO/scripts/publish_list.txt"

echo "Done. Review with: git -C \"$REPO\" status"
exit $missing
