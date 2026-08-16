#!/usr/bin/env bash
set -euo pipefail

# Capture macOS screenshots per language
LANGUAGES=${LANGUAGES:-"en-US uk de-DE fr-FR es-ES ar-SA ur-PK zh-Hans hi pl nl-NL sv tr"}
CACHE_DIR="$HOME/Library/Caches/tools.fastlane/screenshots"
OUTPUT_BASE="fastlane/screenshots/macos"

echo "→ Languages: $LANGUAGES"
rm -rf "$CACHE_DIR"
rm -rf "$OUTPUT_BASE"
mkdir -p "$OUTPUT_BASE"
mkdir -p fastlane/test_output

for LANG in $LANGUAGES; do
  echo ""
  echo "=== $LANG ==="
  mkdir -p "$CACHE_DIR"
  echo "$LANG" > "$CACHE_DIR/language.txt"
  echo "$LANG" > "$CACHE_DIR/locale.txt"
  mkdir -p "$OUTPUT_BASE/$LANG"
  rm -f "$CACHE_DIR"/*.png || true

  xcodebuild test \
    -workspace Piper.xcworkspace \
    -scheme Screenshots \
    -destination "platform=macOS" \
    -resultBundlePath "fastlane/test_output/macos-screenshots-$LANG.xcresult" \
    CODE_SIGNING_ALLOWED=NO

  if [ -d "$CACHE_DIR" ]; then
    count=0
    for f in "$CACHE_DIR"/*.png; do
      [ -e "$f" ] || continue
      cp "$f" "$OUTPUT_BASE/$LANG"/
      count=$((count+1))
    done
    echo "  → $count files → $OUTPUT_BASE/$LANG"
  else
    echo "  ✗ no $CACHE_DIR"
  fi
done

echo ""
echo "Done:"
ls -R "$OUTPUT_BASE" || true
