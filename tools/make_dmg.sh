#!/usr/bin/env bash
# =====================================================================
#  Builds SPRFST-Studio.dmg: a real, mountable disk image holding the
#  app and a shortcut to /Applications.
#
#      ./tools/build_macos_app.sh && ./tools/make_dmg.sh
#      ./tools/make_dmg.sh --stage      assemble the contents only
#
#  --stage lays out exactly what goes inside the image and stops short
#  of calling hdiutil, which exists only on macOS. It is how the layout
#  is checked from a machine that cannot build a disk image.
# =====================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="SPRFST Studio"
VOLUME="SPRFST Studio"
VERSION="$(grep -o '"[0-9][^"]*"' compiler/include/sprfst/common.h | head -1 | tr -d '"')"
DIST="$ROOT/dist"
DMG="$DIST/SPRFST-Studio.dmg"
STAGE="$DIST/dmg-contents"
STAGE_ONLY=0
[ "${1:-}" = "--stage" ] && STAGE_ONLY=1

APP="$DIST/$APP_NAME.app"
[ "$STAGE_ONLY" = 1 ] && [ ! -d "$APP" ] && APP="$DIST/stage/$APP_NAME.app"

amber() { printf '\033[38;5;214m%s\033[0m\n' "$*"; }
step()  { printf '\033[38;5;214m▸\033[0m %s\n' "$*"; }
die()   { printf '\033[38;5;203merror\033[0m %s\n' "$*" >&2; exit 1; }

if [ "$STAGE_ONLY" = 0 ] && [ "$(uname -s)" != "Darwin" ]; then
    die "a .dmg is an Apple disk image and hdiutil is macOS only.
        On a Mac:   ./tools/build_macos_app.sh && ./tools/make_dmg.sh
        Elsewhere:  ./tools/make_dmg.sh --stage   to check the contents"
fi
[ -d "$APP" ] || die "build the app first:  ./tools/build_macos_app.sh$([ "$STAGE_ONLY" = 1 ] && echo ' --stage')"

amber "SPRFST-Studio.dmg  $VERSION$([ "$STAGE_ONLY" = 1 ] && echo '  — staging only')"

step "staging"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/Read me.txt" <<TXT
SPRFST Studio $VERSION

Drag "SPRFST Studio" on to the Applications folder.

The app carries the sprfst compiler inside it. To use the compiler from
a terminal as well, open Studio and run this in its built in terminal:

    sudo mkdir -p /usr/local/bin /usr/local/lib/sprfst
    sudo cp "/Applications/SPRFST Studio.app/Contents/Resources/sprfst" /usr/local/bin/
    sudo cp -R "/Applications/SPRFST Studio.app/Contents/Resources/std" /usr/local/lib/sprfst/

Then  sprfst help  works anywhere.

Everything about the language is in the Guidebook, under Help, or in
guidebook/ in the repository: thirty chapters, every example runnable.
TXT

if [ "$STAGE_ONLY" = 1 ]; then
    echo
    amber "staged  $STAGE"
    (cd "$STAGE" && find . -maxdepth 2 | sed 's|^\./||' | sed '/^$/d' | sed 's|^|    |' | head -20)
    echo "    $(du -sh "$STAGE" | cut -f1) in total"
    echo
    echo "    on a Mac this folder becomes $DMG"
    echo
    exit 0
fi

step "creating the image"
hdiutil create \
    -volname "$VOLUME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    -fs HFS+ \
    "$DMG" >/dev/null

rm -rf "$STAGE"

step "verifying"
hdiutil verify "$DMG" >/dev/null && echo "    image verifies"

MOUNT=$(mktemp -d)
if hdiutil attach "$DMG" -mountpoint "$MOUNT" -nobrowse -quiet; then
    if [ -x "$MOUNT/$APP_NAME.app/Contents/MacOS/SPRFSTStudio" ]; then
        echo "    mounted, and the app inside it is complete"
    else
        echo "    WARNING: the app inside the image has no executable"
    fi
    hdiutil detach "$MOUNT" -quiet
fi
rmdir "$MOUNT" 2>/dev/null || true

SIZE=$(du -sh "$DMG" | cut -f1)
amber "built  $DMG  ($SIZE)"
echo
echo "    open \"$DMG\""
echo
