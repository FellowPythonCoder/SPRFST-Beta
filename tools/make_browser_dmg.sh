#!/usr/bin/env bash
# =====================================================================
#  Builds a mountable disk image of SPRFST Browser.
#
#  On a Mac, after ./tools/build_browser_app.sh, this wraps the built
#  application:     dist/SPRFST-Browser.dmg      (HFS+, compressed,
#                   verified and test mounted with hdiutil)
#
#  Anywhere else there is no Swift compiler, so there is no application
#  to wrap. It builds the installer image instead:
#                   dist/SPRFST-Browser-<version>.dmg   (ISO 9660 with
#                   Joliet names, written by tools/make_iso.spf)
#  which carries the engine, the window's sources and a double
#  clickable installer that builds the app on the Mac it is run on.
#
#      ./tools/make_browser_dmg.sh           build whichever applies
#      ./tools/make_browser_dmg.sh --stage   assemble the contents only
# =====================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="SPRFST Browser"
EXECUTABLE="SPRFSTBrowser"
VERSION="$(grep -o '"[0-9][^"]*"' compiler/include/sprfst/common.h | head -1 | tr -d '"')"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
APP_DMG="$DIST/SPRFST-Browser.dmg"
SRC_DMG="$DIST/SPRFST-Browser-$VERSION.dmg"
STAGE="$DIST/browser-dmg-contents"
STAGE_ONLY=0
[ "${1:-}" = "--stage" ] && STAGE_ONLY=1

amber() { printf '\033[38;5;214m%s\033[0m\n' "$*"; }
step()  { printf '\033[38;5;214m▸\033[0m %s\n' "$*"; }
die()   { printf '\033[38;5;203merror\033[0m %s\n' "$*" >&2; exit 1; }

if [ "$(uname -s)" = "Darwin" ] && [ -x "$APP/Contents/MacOS/$EXECUTABLE" ]; then
    MODE="app"
else
    MODE="installer"
fi

rm -rf "$STAGE"
mkdir -p "$STAGE"

if [ "$MODE" = "app" ]; then
    amber "SPRFST-Browser.dmg  $VERSION"
    step "staging the application"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    cat > "$STAGE/Read me.txt" <<TXT
SPRFST Browser $VERSION

Drag "SPRFST Browser" on to the Applications folder.

WHAT IT IS
A browser whose engine is written in SPRFST: the address parser, the
HTML parser, the style engine, the layout engine and the blocker are
all SPRFST source, inside the app at Contents/Resources/engine. The
window is AppKit, and it only paints what the engine hands it.

THE FIRST TIME
macOS will say the developer cannot be verified, because the app is
signed with an ad hoc signature rather than a paid certificate. Right
click it in Applications and choose Open, once.

WHAT IT BLOCKS
$(grep -cvE '^\s*(~~|!|$)' "$ROOT/browser/privacy-rules/shield.rules" | tr -d ' ') rules, in Contents/Resources/engine/shield.rules. It is a
plain text file; edit it and reopen the browser. sprfst://shield shows
what was stopped on the page you are reading.

WHAT IT CANNOT DO
There is no JavaScript engine, so pages that build themselves in the
browser arrive empty, and anything behind a script will not work. It
is honest about this rather than pretending: no scripts are fetched at
all, which is also why it is quick.
TXT
else
    amber "SPRFST-Browser-$VERSION.dmg  (installer image)"
    step "staging the project"
    FOLDER="$STAGE/SPRFST Browser $VERSION"
    mkdir -p "$FOLDER"
    for item in browser compiler std tools assets tests examples \
                Makefile README.md project.sprfst .gitignore; do
        [ -e "$item" ] && cp -R "$item" "$FOLDER/"
    done
    mkdir -p "$FOLDER/ide/macos"
    cp -R ide/macos/Sources "$FOLDER/ide/macos/Sources"
    rm -rf "$FOLDER/build" "$FOLDER/dist"

    cat > "$STAGE/Install SPRFST Browser.command" <<'CMD'
#!/bin/bash
# =====================================================================
#  Double click to build and install SPRFST Browser on this Mac.
#  The disk image is read only, so everything is copied out first.
# =====================================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(find "$HERE" -maxdepth 1 -type d -name 'SPRFST Browser *' | head -1)"
DEST="$HOME/SPRFST-Browser"

printf '\n\033[38;5;214m  SPRFST Browser\033[0m — building from source\n\n'

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

echo "  building the interpreter"
make

echo "  testing the engine"
(cd browser && "$DEST/build/bin/sprfst" test | tail -3)

if command -v swiftc >/dev/null 2>&1; then
    echo "  building the window"
    ./tools/build_browser_app.sh --install
else
    echo
    echo "  swiftc was not found, so the window was not built."
    echo "  Install the Xcode command line tools and run:"
    echo "      cd \"$DEST\" && ./tools/build_browser_app.sh --install"
    echo
    echo "  The engine works on its own in the meantime:"
    echo "      cd \"$DEST/browser\" && ../build/bin/sprfst run engine/main.spf -- example.com"
fi

echo
read -r -p "  Press return to close. " _
CMD
    chmod +x "$STAGE/Install SPRFST Browser.command"

    RULES=$(grep -cvE '^\s*(~~|!|$)' "$ROOT/browser/privacy-rules/shield.rules" | tr -d ' ')
    cat > "$STAGE/Read me.txt" <<TXT
SPRFST Browser $VERSION

A web browser whose engine is written in SPRFST — the language in this
same image. Nine modules in "SPRFST Browser $VERSION/browser/engine":

    uri.spf      addresses, and what a typed line means
    html.spf     the parser: tags, attributes, entities, bad markup
    css.spf      selectors, declarations, colours, lengths
    shield.spf   the blocker and its rule format
    layout.spf   lines, blocks, lists, images — a display list
    fetch.spf    HTTP over a socket, with a small store
    reader.spf   the Lens: find the article, drop the furniture
    page.spf     one trip: address in, laid out page out
    main.spf     the terminal view, and the service the window drives

WHAT THIS IS NOT
It is not a prebuilt application. The image was produced on Linux,
where Apple's Swift compiler, AppKit and hdiutil do not exist, so no
macOS binary could be put inside it. Rather than ship an app bundle
with nothing in it, the image ships the source and a builder.

TO INSTALL
Double click "Install SPRFST Browser.command". It copies the project
to ~/SPRFST-Browser, builds the interpreter, runs the engine's tests,
then builds "SPRFST Browser.app" and puts it in /Applications. It
needs the Xcode command line tools:

    xcode-select --install

If macOS refuses to open the installer because it came from the
internet, right click it and choose Open, or run it yourself:

    bash "/Volumes/SPRFST Browser/Install SPRFST Browser.command"

BEFORE YOU BUILD ANYTHING
The engine reads pages on its own, in a terminal:

    cd ~/SPRFST-Browser && make
    cd browser && ../build/bin/sprfst run engine/main.spf -- example.com
    ../build/bin/sprfst run engine/main.spf -- --reader en.wikipedia.org/wiki/Web_browser

WHAT IT BLOCKS
$RULES rules in browser/privacy-rules/shield.rules, a plain text file you can
edit. Adverts, trackers, consent walls, chat widgets, cryptominers.
Nothing is sent to Google, including the search: DuckDuckGo's plain
HTML endpoint is the default, and it is one line in sprfst://settings.

WHAT IT CANNOT DO
There is no JavaScript engine. Pages that build themselves in the
browser arrive empty. No script is fetched or run, which is also why
pages that do work are quick: a four kilobyte article is read, styled
and laid out in about six milliseconds.
TXT
fi

if [ "$STAGE_ONLY" = 1 ]; then
    echo
    amber "staged  $STAGE"
    (cd "$STAGE" && find . -maxdepth 2 | sed 's|^\./||' | sed '/^$/d' | sed 's|^|    |' | head -20)
    echo "    $(du -sh "$STAGE" | cut -f1) in total"
    echo
    exit 0
fi

if [ "$MODE" = "app" ]; then
    step "creating the image"
    rm -f "$APP_DMG"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" \
        -ov -format UDZO -fs HFS+ "$APP_DMG" >/dev/null
    rm -rf "$STAGE"

    step "verifying"
    hdiutil verify "$APP_DMG" >/dev/null && echo "    image verifies"
    MOUNT=$(mktemp -d)
    if hdiutil attach "$APP_DMG" -mountpoint "$MOUNT" -nobrowse -quiet; then
        if [ -x "$MOUNT/$APP_NAME.app/Contents/MacOS/$EXECUTABLE" ]; then
            echo "    mounted, and the app inside it is complete"
        else
            echo "    WARNING: the app inside the image has no executable"
        fi
        hdiutil detach "$MOUNT" -quiet
    fi
    rmdir "$MOUNT" 2>/dev/null || true
    DMG="$APP_DMG"
else
    [ -x build/bin/sprfst ] || die "build the interpreter first:  make"
    step "writing the image (ISO 9660 with Joliet names)"
    mkdir -p "$DIST"
    rm -f "$SRC_DMG"
    SPRFST_HOME="$ROOT" ./build/bin/sprfst run tools/make_iso.spf -- \
        "$STAGE" "$SRC_DMG" "SPRFST Browser"
    rm -rf "$STAGE"
    DMG="$SRC_DMG"
fi

SIZE=$(du -sh "$DMG" | cut -f1)
amber "built  $DMG  ($SIZE)"
echo
echo "    open \"$DMG\""
echo
