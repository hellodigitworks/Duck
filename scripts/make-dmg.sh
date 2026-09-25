#!/bin/zsh
# Packs a built Duck.app into build/Duck.dmg, the file people download from the site: open
# it, and a window shows Duck beside the Applications folder with an arrow between them.
# Run by make-app.sh --release, which notarises the result afterwards. On its own:
#   zsh scripts/make-dmg.sh <path to Duck.app> [signing identity]
set -e
cd "$(dirname "$0")/.."

APP="${1:?Pass the path to Duck.app}"
IDENTITY="${2:--}"
SCRATCH="$HOME/Library/Caches/duck-build"
DMG="build/Duck.dmg"

# dmgbuild lays the window out by writing Finder's layout file directly, so nothing has to
# open Finder or ask for permission to control it. It lives in its own Python environment
# in the build cache, installed the first time and reused after.
VENV="$SCRATCH/dmg-venv"
if [ ! -x "$VENV/bin/dmgbuild" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q dmgbuild
fi

# The picture behind the window, in both sizes, joined into one file Finder reads either way.
ART="$SCRATCH/dmg-art"
swift scripts/make-dmg-background.swift "$ART"
tiffutil -cathidpicheck "$ART/background.png" "$ART/background@2x.png" -out "$ART/background.tiff" 2>/dev/null

# Icon positions match make-dmg-background.swift, which draws the arrow between them.
SETTINGS="$SCRATCH/dmg-settings.py"
cat > "$SETTINGS" <<PY
app = "$APP"
files = [app]
symlinks = {"Applications": "/Applications"}
background = "$ART/background.tiff"
icon = "$APP/Contents/Resources/AppIcon.icns"
format = "UDZO"
filesystem = "APFS"
window_rect = ((200, 160), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 112
text_size = 13
icon_locations = {"Duck.app": (180, 180), "Applications": (460, 180)}
PY

mkdir -p build
rm -f "$DMG"
"$VENV/bin/dmgbuild" -s "$SETTINGS" "Duck" "$DMG"

# The disk image carries its own signature, so macOS can check it before it is even opened.
if [ "$IDENTITY" != "-" ]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  codesign --verify "$DMG"
fi
echo "Built: $DMG"
