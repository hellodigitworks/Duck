#!/bin/zsh
# Builds Duck.app from source. Run: zsh scripts/make-app.sh [--install] [--release]
#   --install  copy the finished app into /Applications
#   --release  also write build/Duck.zip, the file to attach to a GitHub release
set -e
cd "$(dirname "$0")/.."

APP_NAME="Duck"
BUNDLE_ID="com.hdw.duck"
# One version, one place. The VERSION file at the project root is the source;
# make-cask.py reads the built app, and the app itself reads the number back out
# of its own Info.plist, so this is the only line that ever needs changing.
VERSION="$(tr -d ' \n' < VERSION)"
BUILD_NUMBER="11"

# Build outside the Google Drive folder: Drive sync corrupts incremental
# build state (files appear where directories should be).
SCRATCH="$HOME/Library/Caches/duck-build"
swift build -c release --scratch-path "$SCRATCH"

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SCRATCH/release/Duck" "$APP/Contents/MacOS/Duck"
# Symbol names are only useful to a debugger. Dropping them halves the binary.
strip "$APP/Contents/MacOS/Duck"

if [ ! -f icons/AppIcon.icns ]; then
  swift scripts/make-icon.swift
fi
cp icons/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# The duck itself, for the foot of the window, and the dark Dock tile.
cp icons/duck.svg "$APP/Contents/Resources/duck.svg"
cp icons/AppIcon-dark.png "$APP/Contents/Resources/AppIcon-dark.png"

# What changed, so the window can show it without a network call.
cp CHANGELOG.md "$APP/Contents/Resources/CHANGELOG.md"

# The two faces the window uses, Exposure and Inter. macOS registers everything in Resources/Fonts on its own
# (ATSApplicationFontsPath below), so there is no font code in the app at all.
mkdir -p "$APP/Contents/Resources/Fonts"
cp fonts/ExposureTrial-30.otf fonts/Inter-*.ttf fonts/OFL-Inter.txt "$APP/Contents/Resources/Fonts/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>Duck</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 hdw</string>
    <key>ATSApplicationFontsPath</key>
    <string>Fonts</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for a locally built app to run and remember its settings.
codesign --force --deep --sign - "$APP"
echo "Built: $APP"

for flag in "$@"; do
  case "$flag" in
    # Install to /Applications so it behaves like a real app and can start at login.
    --install)
      pkill -x Duck 2>/dev/null || true
      sleep 1
      rm -rf "/Applications/$APP_NAME.app"
      cp -R "$APP" "/Applications/$APP_NAME.app"
      echo "Installed: /Applications/$APP_NAME.app"
      ;;
    # The zip people download. ditto keeps the bundle intact, unlike plain zip. No version
    # in the name, so the landing page's link to the latest release never goes stale.
    --release)
      ZIP="build/$APP_NAME.zip"
      rm -f "$ZIP"
      ditto -c -k --keepParent "$APP" "$ZIP"
      echo "Release: $ZIP ($(du -h "$ZIP" | cut -f1))"
      ;;
    *)
      echo "Unknown flag: $flag" >&2
      exit 1
      ;;
  esac
done
