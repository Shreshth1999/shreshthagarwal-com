#!/bin/bash
# Deploy shreshthagarwal.com
#
# The domain resolves to 13.234.147.201 and is served by Caddy as a plain
# file_server out of /var/www/shreshthagarwal. It is NOT served from S3.
#
# The previous version of this script synced to an S3 bucket named
# shreshthagarwal.com. That bucket still answers on its website endpoint, so the
# script looked like it worked, but nothing it uploaded ever reached the domain.
# If you want that bucket gone, delete it deliberately; this script ignores it.
#
# Usage: ./deploy.sh            deploy
#        ./deploy.sh --dry-run  show what would change, touch nothing

set -euo pipefail

HOST="ubuntu@13.234.147.201"
KEY="$HOME/.ssh/h4e-deploy.pem"
LIVE="/var/www/shreshthagarwal"
STAGE="/tmp/site-deploy-$$"
HERE="$(cd "$(dirname "$0")" && pwd)"

DRY=""
[ "${1:-}" = "--dry-run" ] && DRY="--dry-run"

# Never publish these. Shreshth-Agarwal-CV carries eight referees' personal
# mobile numbers and Gmail addresses; that is their data, not ours to publish.
EXCLUDES=(
  --exclude '.git'            --exclude '.gitignore'
  --exclude 'deploy.sh'       --exclude '*.md'
  --exclude '.DS_Store'       --exclude 'generate-cv-pdf.mjs'
  --exclude 'Shreshth-Agarwal-CV*'
  --exclude 'node_modules'    --exclude '.venv'
  --exclude '.gstack'         --exclude 'index.html.*'
  --exclude '*.bak'
)

echo "==> Pre-flight"
[ -f "$KEY" ] || { echo "    missing deploy key at $KEY"; exit 1; }
[ -f "$HERE/index.html" ] || { echo "    no index.html in $HERE"; exit 1; }
if ls "$HERE"/Shreshth-Agarwal-CV* >/dev/null 2>&1; then
  echo "    note: Shreshth-Agarwal-CV present locally and excluded from the upload"
fi
echo "    source: $HERE"
echo "    target: $HOST:$LIVE"

echo "==> Backing up what is live"
BK=$(ssh -i "$KEY" -o StrictHostKeyChecking=no "$HOST" \
  'TS=$(date +%Y%m%d-%H%M%S); BK=/home/ubuntu/site-full-backup-$TS;
   sudo cp -a '"$LIVE"' "$BK" && sudo chown -R ubuntu:ubuntu "$BK" && echo "$BK"')
echo "    $BK"

echo "==> Staging"
ssh -i "$KEY" -o StrictHostKeyChecking=no "$HOST" "rm -rf $STAGE && mkdir -p $STAGE"
rsync -az --delete $DRY "${EXCLUDES[@]}" \
  -e "ssh -i $KEY -o StrictHostKeyChecking=no" \
  "$HERE"/ "$HOST:$STAGE/"

if [ -n "$DRY" ]; then
  echo "==> Dry run, nothing published. Staging left at $STAGE"
  exit 0
fi

echo "==> Publishing"
ssh -i "$KEY" -o StrictHostKeyChecking=no "$HOST" "
  set -e
  test -f $STAGE/index.html
  test ! -e $STAGE/Shreshth-Agarwal-CV.pdf
  sudo rsync -a --delete $STAGE/ $LIVE/
  sudo chown -R root:root $LIVE
  sudo find $LIVE -type f -exec chmod 644 {} \;
  sudo find $LIVE -type d -exec chmod 755 {} \;
  rm -rf $STAGE
"

echo "==> Verifying"
fail=0
for p in / /cv.pdf /portrait.jpg /r/ /rooms/rooms.json; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 25 "https://shreshthagarwal.com$p")
  printf "    %-22s %s\n" "$p" "$code"
  [ "$code" = "200" ] || fail=$((fail + 1))
done
# the referee CV must not be reachable
code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 20 "https://shreshthagarwal.com/Shreshth-Agarwal-CV.pdf")
printf "    %-22s %s (404 expected)\n" "/Shreshth-Agarwal-CV.pdf" "$code"
[ "$code" = "404" ] || fail=$((fail + 1))

if [ "$fail" -gt 0 ]; then
  echo "==> $fail check(s) failed. Roll back with:"
  echo "    ssh -i $KEY $HOST 'sudo rsync -a --delete $BK/ $LIVE/'"
  exit 1
fi

echo "==> Live. Roll back if needed with:"
echo "    ssh -i $KEY $HOST 'sudo rsync -a --delete $BK/ $LIVE/'"
