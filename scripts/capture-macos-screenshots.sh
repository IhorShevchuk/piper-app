#!/usr/bin/env bash
set -euo pipefail

if [ -d fastlane/metadata ]; then
  DEFAULT_LANGS=$(ls -1 fastlane/metadata | tr '\n' ' ')
else
  DEFAULT_LANGS="en-US"
fi
LANGUAGES=${LANGUAGES:-$DEFAULT_LANGS}

CACHE_BASE="$HOME/Library/Caches/tools.fastlane"
CACHE_SCREENSHOTS="$CACHE_BASE/screenshots"
OUTPUT_BASE="fastlane/screenshots/macos"

echo "→ Languages (from fastlane/metadata): $LANGUAGES"
echo "→ Cache base: $CACHE_BASE"
rm -rf "$CACHE_SCREENSHOTS"
rm -rf "$OUTPUT_BASE"
mkdir -p "$OUTPUT_BASE"
mkdir -p fastlane/test_output
mkdir -p "$CACHE_BASE"

for LANG in $LANGUAGES; do
  echo ""
  echo "=== $LANG ==="
  mkdir -p "$CACHE_SCREENSHOTS"
  echo "$LANG" > "$CACHE_BASE/language.txt"
  echo "$LANG" > "$CACHE_BASE/locale.txt"
  mkdir -p "$OUTPUT_BASE/$LANG"
  rm -f "$CACHE_SCREENSHOTS"/*.png || true

  echo "  writing $CACHE_BASE/language.txt = $LANG"
  cat "$CACHE_BASE/language.txt"

  xcodebuild test \
    -workspace Piper.xcworkspace \
    -scheme Screenshots \
    -destination "platform=macOS" \
    -resultBundlePath "fastlane/test_output/macos-screenshots-$LANG.xcresult" \
    CODE_SIGNING_ALLOWED=NO

  if [ -d "$CACHE_SCREENSHOTS" ]; then
    count=0
    for f in "$CACHE_SCREENSHOTS"/*.png; do
      [ -e "$f" ] || continue
      cp "$f" "$OUTPUT_BASE/$LANG"/
      count=$((count+1))
    done
    echo "  → $count files → $OUTPUT_BASE/$LANG"
    ls -1 "$OUTPUT_BASE/$LANG" 2>/dev/NULL | head
  else
    echo "  ✗ no $CACHE_SCREENSHOTS"
  fi
done

echo ""
ls -R "$OUTPUT_BASE" || true
