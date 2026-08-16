#!/usr/bin/env bash
set -euo pipefail

# Capture macOS screenshots for App Store Connect
# Works around fastlane snapshot not officially supporting macOS:
# - Runs the Screenshots UI test bundle for platform=macOS
# - SnapshotHelper (macOS path) writes PNGs via NSBitmapImageRep into
#   ~/Library/Caches/tools.fastlane/screenshots
# - This script collects them into fastlane/screenshots/macos/en-US

OUTPUT_DIR="fastlane/screenshots/macos/en-US"
CACHE_DIR="$HOME/Library/Caches/tools.fastlane/screenshots"

echo "→ Cleaning previous macOS screenshots"
rm -rf "$CACHE_DIR"
rm -rf fastlane/screenshots/macos
mkdir -p "$OUTPUT_DIR"
mkdir -p fastlane/test_output

echo "→ Running Screenshots scheme for macOS"
# Using xcodebuild directly so we don't depend on fastlane snapshot action
xcodebuild test \
  -workspace Piper.xcworkspace \
  -scheme Screenshots \
  -destination "platform=macOS" \
  -resultBundlePath "fastlane/test_output/macos-screenshots.xcresult" \
  CODE_SIGNING_ALLOWED=NO

echo "→ Collecting screenshots from $CACHE_DIR"
if [ -d "$CACHE_DIR" ]; then
  find "$CACHE_DIR" -type f -name "*.png" | while read -r f; do
    echo "  copying $(basename "$f")"
    cp "$f" "$OUTPUT_DIR"/
  done
  echo "→ Done: $(ls -1 "$OUTPUT_DIR" | wc -l) files in $OUTPUT_DIR"
  ls -lh "$OUTPUT_DIR"
else
  echo "✗ No cache dir $CACHE_DIR found"
  echo "  Check Xcode test log – Snapshot logs to NSLog"
  exit 1
fi

# App Store Connect expects 1280x800 minimum for Mac; we don't resize here but warn
for img in "$OUTPUT_DIR"/*.png; do
  dims=$(sips -g pxWidth -g pxHeight "$img" 2>/dev/NULL | awk '/px/ {printf "%sx%s ", $2, $1}'; echo)
  echo "  $img $dims"
done

echo "Ready for: fastlane mac appstore_upload or deliver --screenshots_path fastlane/screenshots/macos"
