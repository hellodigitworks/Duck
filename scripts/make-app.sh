#!/bin/zsh
# Builds Duck.app from source. Run: zsh scripts/make-app.sh [--install] [--release]
#   --install  copy the finished app into /Applications
#   --release  also notarise it with Apple and write build/Duck.dmg and build/Duck.zip,
#              the two files to attach to a GitHub release
set -e
cd "$(dirname "$0")/.."

APP_NAME="Duck"
BUNDLE_ID="com.hdw.duck"
# One version, one place. The VERSION file at the project root is the source;
# make-cask.py reads the built app, and the app itself reads the number back out
# of its own Info.plist, so this is the only line that ever needs changing.
VERSION="$(tr -d ' \n' < VERSION)"
SPARKLE_FRAMEWORK="$HOME/Library/Caches/duck-build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
PUBLIC_UPDATE_KEY="wLpwGKikogE3sOXZGvFoZzMSYr540Ek4DQgAR3CpvS0="

# Build outside the Google Drive folder: Drive sync corrupts incremental
# build state (files appear where directories should be).
SCRATCH="$HOME/Library/Caches/duck-build"
swift build -c release --scratch-path "$SCRATCH"

# The app is assembled out here too. Drive stamps everything it syncs with tags of its
# own, and one tagged file anywhere inside a bundle makes the signature fail to verify,
# which is enough to stop an update installing. Only the finished zip comes back into
# the project folder.
APP="$SCRATCH/app/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SCRATCH/release/Duck" "$APP/Contents/MacOS/Duck"
# Symbol names are only useful to a debugger. Dropping them halves the binary.
strip "$APP/Contents/MacOS/Duck"
# Swift links Sparkle beside the executable while building. Inside an app it belongs in
# Contents/Frameworks, so add the app location before signing the executable.
mkdir -p "$APP/Contents/Frameworks"
cp -R "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Duck"

if [ ! -f icons/AppIcon.icns ] || [ ! -d icons/AppIcon.icon ]; then
  swift scripts/make-icon.swift
fi
# Two icons. macOS 26 and later read Assets.car, compiled here from the Icon Composer
# document, and draw it in glass with a proper dark look. Older versions read the .icns.
# actool writes a .icns of its own too, which is dropped: ours is the one older Macs know.
# actool cannot read the document straight out of the Drive folder, so it gets a copy.
ICON_OUT="$SCRATCH/icon"
rm -rf "$ICON_OUT"
mkdir -p "$ICON_OUT"
ditto icons/AppIcon.icon "$ICON_OUT/AppIcon.icon"
xcrun actool "$ICON_OUT/AppIcon.icon" --compile "$ICON_OUT" --platform macosx \
  --minimum-deployment-target 13.0 --app-icon AppIcon \
  --output-partial-info-plist "$ICON_OUT/partial.plist" --errors --warnings > /dev/null
cp "$ICON_OUT/Assets.car" "$APP/Contents/Resources/Assets.car"
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
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <!-- The same number again, not a build count: Sparkle compares the feed's
         sparkle:version against this key, so the two have to agree or every
         copy is offered the release it is already running. -->
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
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
    <key>SUFeedURL</key>
    <string>https://duck.hellodigitworks.com/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>$PUBLIC_UPDATE_KEY</string>
    <!-- Duck looks for a newer release once a day on its own, so nobody is asked for
         permission to look on first launch. It still asks before it installs. -->
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
</dict>
</plist>
PLIST

# Signed with hdw's Developer ID, the certificate Apple issues to its developer program, so
# macOS knows who made Duck and opens it without a warning. Without that certificate in the
# keychain (another Mac, say) the build falls back to an ad-hoc signature, fine for trying it
# locally and refused by --release.
# Hardened runtime (-o runtime) and a timestamp from Apple are both required before Apple
# will notarise the app. Signing goes from the inside out: every piece of Sparkle first,
# then the framework, then the app around them. --deep would sign them all the same way,
# which Apple warns against because the pieces need different treatment.
IDENTITY="Developer ID Application: Swayam Bhansali (3NLU2459VW)"
if security find-identity -v -p codesigning | grep -qF "$IDENTITY"; then
  SIGN=(codesign --force --options runtime --timestamp --sign "$IDENTITY")
else
  IDENTITY="-"
  SIGN=(codesign --force --sign -)
  echo "No Developer ID in this keychain. Signing ad-hoc, for this Mac only." >&2
fi
xattr -cr "$APP"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
"${SIGN[@]}" "$SPARKLE/XPCServices/Installer.xpc"
"${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
"${SIGN[@]}" "$SPARKLE/Autoupdate"
"${SIGN[@]}" "$SPARKLE/Updater.app"
"${SIGN[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
"${SIGN[@]}" "$APP"
# The verify is not a formality: a bundle can sign cleanly and still fail to open.
codesign --verify --deep --strict "$APP"
echo "Built: $APP (signed: $IDENTITY)"

# Hands one file to Apple's notary service and waits for its answer, usually a minute or
# two. Apple scans it and records that it is clean. The login is saved in this Mac's
# keychain under the name duck-notary (xcrun notarytool store-credentials duck-notary).
notarise() {
  echo "Notarising $(basename "$1"), usually a minute or two…"
  local out
  out="$(xcrun notarytool submit "$1" --keychain-profile duck-notary --wait --timeout 30m 2>&1)" || true
  echo "$out"
  if ! grep -q "status: Accepted" <<< "$out"; then
    echo "Apple did not accept $(basename "$1"). Its reasons:" >&2
    local id="$(awk '/^ *id:/ { print $2; exit }' <<< "$out")"
    [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile duck-notary >&2
    exit 1
  fi
}

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
    # The two files a release carries, both notarised. Duck.dmg is what people download
    # from the site. Duck.zip is what Sparkle and Homebrew fetch. ditto keeps the bundle
    # intact, unlike plain zip. No version in either name, so the landing page's link to
    # the latest release never goes stale.
    --release)
      [ "$IDENTITY" != "-" ] || { echo "A release needs the Developer ID in the keychain." >&2; exit 1; }
      ZIP="build/$APP_NAME.zip"
      mkdir -p build
      rm -f "$ZIP"
      # Apple takes a zip, not a bare app. It records its answer against the app inside,
      # and staple pins a copy of that answer to the app itself, so it opens clean even
      # with no connection. The zip is then made again, from the stapled app.
      # --norsrc --noextattr so nothing Drive or Finder attached rides along inside.
      ditto -c -k --keepParent --norsrc --noextattr "$APP" "$ZIP"
      notarise "$ZIP"
      xcrun stapler staple "$APP"
      rm -f "$ZIP"
      ditto -c -k --keepParent --norsrc --noextattr "$APP" "$ZIP"
      spctl --assess --type execute "$APP"
      echo "Release: $ZIP ($(du -h "$ZIP" | cut -f1))"
      zsh scripts/make-dmg.sh "$APP" "$IDENTITY"
      notarise "build/$APP_NAME.dmg"
      xcrun stapler staple "build/$APP_NAME.dmg"
      spctl --assess --type open --context context:primary-signature "build/$APP_NAME.dmg"
      echo "Release: build/$APP_NAME.dmg ($(du -h "build/$APP_NAME.dmg" | cut -f1))"
      ;;
    *)
      echo "Unknown flag: $flag" >&2
      exit 1
      ;;
  esac
done
