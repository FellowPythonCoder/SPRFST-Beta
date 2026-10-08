#!/usr/bin/env bash
# =====================================================================
#  Builds a mountable disk image.
#
#  On a Mac, after ./tools/build_macos_app.sh, this wraps the built
#  application:            dist/SPRFST-Studio.dmg   (HFS+, compressed,
#                          verified and test mounted with hdiutil)
#
#  Anywhere else there is no Swift compiler, so there is no application
#  to wrap. It builds the installer image instead:
#                          dist/SPRFST-<version>.dmg   (ISO 9660 with
#                          Joliet names, written by tools/make_iso.spf)
#  which carries the whole project and a double-clickable installer
#  that builds Studio on the Mac it is run on.
#
#      ./tools/make_dmg.sh           build whichever applies
#      ./tools/make_dmg.sh --stage   assemble the contents only
# =====================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="SPRFST Studio"
VERSION="$(grep -o '"[0-9][^"]*"' compiler/include/sprfst/common.h | head -1 | tr -d '"')"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
APP_DMG="$DIST/SPRFST-Studio.dmg"
SRC_DMG="$DIST/SPRFST-$VERSION.dmg"
STAGE="$DIST/dmg-contents"
STAGE_ONLY=0
[ "${1:-}" = "--stage" ] && STAGE_ONLY=1

amber() { printf '\033[38;5;214m%s\033[0m\n' "$*"; }
step()  { printf '\033[38;5;214m▸\033[0m %s\n' "$*"; }
die()   { printf '\033[38;5;203merror\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------
#  Which image are we making?
# ---------------------------------------------------------------------
if [ "$(uname -s)" = "Darwin" ] && [ -x "$APP/Contents/MacOS/SPRFSTStudio" ]; then
    MODE="app"
else
    MODE="installer"
fi

rm -rf "$STAGE"
mkdir -p "$STAGE"

if [ "$MODE" = "app" ]; then
    amber "SPRFST-Studio.dmg  $VERSION"
    step "staging the application"
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

Everything about the language is in the Guidebook, under Help: thirty
chapters, every example runnable.
TXT
else
    amber "SPRFST-$VERSION.dmg  (installer image)"
    step "staging the project"
    FOLDER="$STAGE/SPRFST $VERSION"
    mkdir -p "$FOLDER"
    # everything a Mac needs to build the whole thing, and nothing else
    for item in compiler std examples guidebook docs ide tools assets tests \
                Makefile README.md RUNNING.md project.sprfst .gitignore; do
        [ -e "$item" ] && cp -R "$item" "$FOLDER/"
    done
    rm -rf "$FOLDER/build" "$FOLDER/dist"

    cat > "$STAGE/Install SPRFST.command" <<'CMD'
#!/bin/bash
# =====================================================================
#  Double click to build and install SPRFST Studio on this Mac.
#  The disk image is read only, so everything is copied out first.
# =====================================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(find "$HERE" -maxdepth 1 -type d -name 'SPRFST *' | head -1)"
DEST="$HOME/SPRFST"

printf '\n\033[38;5;214m  SPRFST\033[0m — building from source\n\n'

if ! command -v cc >/dev/null 2>&1; then
    echo "  The Xcode command line tools are needed. Run this, then try again:"
    echo
    echo "      xcode-select --install"
    echo
    read -r -p "  Press return to close. " _; exit 1
fi

echo "  copying the project to $DEST"
mkdir -p "$DEST"
cp -R "$SRC"/. "$DEST"/
chmod -R u+w "$DEST"
cd "$DEST"

echo "  building the compiler"
make

echo "  running the tests"
./tests/run_tests.sh | tail -3

if command -v swiftc >/dev/null 2>&1; then
    echo "  building SPRFST Studio"
    ./tools/build_macos_app.sh
    if [ -d "dist/SPRFST Studio.app" ]; then
        echo "  installing to /Applications"
        rm -rf "/Applications/SPRFST Studio.app"
        cp -R "dist/SPRFST Studio.app" /Applications/
        open -R "/Applications/SPRFST Studio.app" || true
    fi
else
    echo
    echo "  swiftc was not found, so Studio was not built."
    echo "  The language, the compiler and everything else still work:"
fi

echo
echo "  the compiler is at $DEST/build/bin/sprfst"
echo "  try:   cd \"$DEST\" && ./build/bin/sprfst run examples/01-hello.spf"
echo
read -r -p "  Press return to close. " _
CMD
    chmod +x "$STAGE/Install SPRFST.command"

    cat > "$STAGE/Read me.txt" <<TXT
SPRFST $VERSION

This image carries the whole project: the language, its compiler and
runtime in C, the standard library, twenty one examples, the thirty
chapter guidebook, the toolchain, and SPRFST Studio's AppKit sources.

WHAT THIS IS NOT
It is not a prebuilt application. The image was produced on Linux,
where Apple's Swift compiler, AppKit and hdiutil do not exist, so no
macOS binary could be put inside it. Rather than ship an app bundle
with nothing in it, the image ships the source and a builder.

TO INSTALL
Double click "Install SPRFST.command". It copies the project to
~/SPRFST, builds the compiler, runs the test suite, then builds
SPRFST Studio and puts it in /Applications. It needs the Xcode
command line tools:

    xcode-select --install

If macOS refuses to open the installer because it came from the
internet, either right click it and choose Open, or run it yourself:

    bash "/Volumes/SPRFST/Install SPRFST.command"

EVERY COMMAND, STEP BY STEP
"SPRFST $VERSION/RUNNING.md" is the terminal guide: build it, run it,
install it, debug it, and build Studio, with the output of each step.

TO LOOK AROUND FIRST
Everything is readable as it sits. The guidebook is in
"SPRFST $VERSION/guidebook" — thirty chapters of Markdown, every code
block runnable once the compiler is built.

    cd ~/SPRFST
    make
    ./build/bin/sprfst run examples/01-hello.spf
    ./build/bin/sprfst help
TXT
fi

if [ "$STAGE_ONLY" = 1 ]; then
    echo
    amber "staged  $STAGE"
    (cd "$STAGE" && find . -maxdepth 2 | sed 's|^\./||' | sed '/^$/d' | sed 's|^|    |' | head -24)
    echo "    $(du -sh "$STAGE" | cut -f1) in total"
    echo
    exit 0
fi

# ---------------------------------------------------------------------
#  Build the image
# ---------------------------------------------------------------------
if [ "$MODE" = "app" ]; then
    step "creating the image"
    rm -f "$APP_DMG"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGE" \
        -ov -format UDZO \
        -fs HFS+ \
        "$APP_DMG" >/dev/null
    rm -rf "$STAGE"

    step "verifying"
    hdiutil verify "$APP_DMG" >/dev/null && echo "    image verifies"
    MOUNT=$(mktemp -d)
    if hdiutil attach "$APP_DMG" -mountpoint "$MOUNT" -nobrowse -quiet; then
        if [ -x "$MOUNT/$APP_NAME.app/Contents/MacOS/SPRFSTStudio" ]; then
            echo "    mounted, and the app inside it is complete"
        else
            echo "    WARNING: the app inside the image has no executable"
        fi
        hdiutil detach "$MOUNT" -quiet
    fi
    rmdir "$MOUNT" 2>/dev/null || true
    DMG="$APP_DMG"
else
    [ -x build/bin/sprfst ] || die "build the compiler first:  make"
    step "writing the image (ISO 9660 with Joliet names)"
    mkdir -p "$DIST"
    rm -f "$SRC_DMG"
    SPRFST_HOME="$ROOT" ./build/bin/sprfst run tools/make_iso.spf -- \
        "$STAGE" "$SRC_DMG" "SPRFST"
    rm -rf "$STAGE"
    DMG="$SRC_DMG"
fi

SIZE=$(du -sh "$DMG" | cut -f1)
amber "built  $DMG  ($SIZE)"
echo
echo "    open \"$DMG\""
echo
