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
DERIVED_DATA="/tmp/snapshot_derived_macos"

echo "→ Languages (from fastlane/metadata): $LANGUAGES"
echo "→ Cleaning test_output + screenshots"
rm -rf fastlane/test_output
mkdir -p fastlane/test_output
rm -rf "$CACHE_SCREENSHOTS"
mkdir -p "$CACHE_SCREENSHOTS"
rm -rf "$OUTPUT_BASE"
mkdir -p "$OUTPUT_BASE"
mkdir -p "$CACHE_BASE"

# One-time build – avoids rebuilding Piper + SwiftLint for each language
# FASTLANE_SNAPSHOT=YES makes Project.swift skip SwiftLint phases (speedup)
export FASTLANE_SNAPSHOT=YES
echo "→ Building Screenshots scheme once for macOS (no code signing)"
xcodebuild build-for-testing \
  -workspace Piper.xcworkspace \
  -scheme Screenshots \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO | xcpretty

for LANG in $LANGUAGES; do
  echo ""
  echo "=== $LANG ==="
  mkdir -p "$CACHE_SCREENSHOTS"
  echo "$LANG" > "$CACHE_BASE/language.txt"
  echo "$LANG" > "$CACHE_BASE/locale.txt"
  echo "  LANG=$LANG locale=$LANG (RTL if ar-SA / ur-PK – system mirrors SwiftUI automatically)"
  mkdir -p "$OUTPUT_BASE/$LANG"
  rm -rf "fastlane/test_output/macos-screenshots-$LANG.xcresult" || true
  rm -f "$CACHE_SCREENSHOTS"/*.png || true

  xcodebuild test-without-building \
    -workspace Piper.xcworkspace \
    -scheme Screenshots \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -resultBundlePath "fastlane/test_output/macos-screenshots-$LANG.xcresult" \
    CODE_SIGNING_ALLOWED=NO | xcpretty

  if [ -d "$CACHE_SCREENSHOTS" ]; then
    count=0
    for f in "$CACHE_SCREENSHOTS"/*.png; do
      [ -e "$f" ] || continue
      cp "$f" "$OUTPUT_BASE/$LANG"/
      count=$((count+1))
    done
    echo "  → $count files → $OUTPUT_BASE/$LANG"
  fi
done

ls -R "$OUTPUT_BASE" || true
