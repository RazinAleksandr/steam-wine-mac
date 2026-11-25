#!/bin/bash
# Regenerates the README artwork in docs/ and the launcher icons.
# Needs Xcode Command Line Tools (swiftc, iconutil) and ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/../.."
WORK="$(mktemp -d)"
xcrun swiftc -O -swift-version 5 -o "$WORK/render" docs/generate/render.swift -framework AppKit -framework SwiftUI
"$WORK/render" docs "$WORK"

# README icon
sips -Z 256 "$WORK/icon-1024.png" --out docs/icon.png >/dev/null

# launcher icons (.icns)
make_icns() { # source png, destination .app
  local set="$WORK/AppIcon.iconset"; rm -rf "$set"; mkdir -p "$set"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$1" --out "$set/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$1" --out "$set/icon_${s}x${s}@2x.png" >/dev/null
  done
  mkdir -p "$2/Contents/Resources"
  iconutil -c icns "$set" -o "$2/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$2/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$2/Contents/Info.plist"
}
make_icns "$WORK/icon-1024.png" "Steam (winebox).app"
make_icns "$WORK/icon-play-1024.png" "Deadlock.app"

# terminal demo
ffmpeg -loglevel error -y -framerate 14 -i "$WORK/frames/f%03d.png" \
  -vf "scale=900:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=sierra2_4a" \
  -loop 0 docs/demo.gif

for f in docs/banner*.png; do sips -Z 1600 "$f" >/dev/null; done
for f in docs/stack*.png; do sips -Z 1100 "$f" >/dev/null; done
rm -rf "$WORK"
ls -lh docs
