#!/usr/bin/env bash
# =====================================================================
#  Builds "SPRFST Studio.app" for Apple Silicon.
#
#      ./tools/build_macos_app.sh            full build (needs macOS)
#      ./tools/build_macos_app.sh --stage    lay the bundle out only
#
#  The bundle carries the compiler, the standard library, the examples
#  and the guidebook, so the app works on a machine with nothing else
#  installed.
#
#  --stage does everything that is not Mac specific: the icon, the
#  Info.plist, the resources. It runs anywhere, and is how the layout
#  is checked on a machine that has no Swift. The staged bundle has no
#  executable in it and will not run; it goes in dist/stage/ so it can
#  never be mistaken for the real thing.
# =====================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="SPRFST Studio"
BUNDLE_ID="ai.sprfst.studio"
VERSION="$(grep -o '"[0-9][^"]*"' compiler/include/sprfst/common.h | head -1 | tr -d '"')"
ARCH="${SPRFST_ARCH:-arm64}"
STAGE_ONLY=0
[ "${1:-}" = "--stage" ] && STAGE_ONLY=1

DIST="$ROOT/dist"
[ "$STAGE_ONLY" = 1 ] && DIST="$ROOT/dist/stage"
APP="$DIST/$APP_NAME.app"

amber() { printf '\033[38;5;214m%s\033[0m\n' "$*"; }
step()  { printf '\033[38;5;214m▸\033[0m %s\n' "$*"; }
die()   { printf '\033[38;5;203merror\033[0m %s\n' "$*" >&2; exit 1; }

if [ "$STAGE_ONLY" = 0 ]; then
    [ "$(uname -s)" = "Darwin" ] || die "this builds a macOS bundle and must run on macOS — try --stage"
    command -v swiftc >/dev/null || die "swiftc not found — run  xcode-select --install"
fi

amber "SPRFST Studio $VERSION  ($ARCH)$([ "$STAGE_ONLY" = 1 ] && echo '  — staging only')"

# ----------------------------------------------------------- compiler
step "building the compiler"
make -j"$( (command -v sysctl >/dev/null && sysctl -n hw.ncpu) || nproc || echo 4)" >/dev/null
[ -x build/bin/sprfst ] || die "the compiler did not build"

step "running the test suite"
./tests/run_tests.sh >/dev/null || die "tests failed — not packaging a broken build"

step "checking the Studio sources"
./tools/check_swift.sh >/dev/null || die "the Swift sources did not pass their static checks"

# -------------------------------------------------------------- icons
step "drawing the icons with SPRFST itself"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
SPRFST_HOME="$ROOT" ./build/bin/sprfst run assets/logo/make_icons.spf >/dev/null
SPRFST_HOME="$ROOT" ./build/bin/sprfst run assets/logo/make_icns.spf -- "$APP/Contents/Resources/SPRFST.icns" >/dev/null

# ------------------------------------------------------------ bundle
step "laying out the bundle"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>SPRFSTStudio</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>SPRFST</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>NSRequiresAquaSystemAppearance</key><false/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>SPRFST source</string>
            <key>CFBundleTypeExtensions</key><array><string>spf</string></array>
            <key>CFBundleTypeIconFile</key><string>SPRFST</string>
            <key>CFBundleTypeRole</key><string>Editor</string>
            <key>LSHandlerRank</key><string>Owner</string>
        </dict>
        <dict>
            <key>CFBundleTypeName</key><string>SPRFST project</string>
            <key>CFBundleTypeExtensions</key><array><string>sprfst</string></array>
            <key>CFBundleTypeRole</key><string>Editor</string>
            <key>LSHandlerRank</key><string>Owner</string>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key><string>ai.sprfst.source</string>
            <key>UTTypeDescription</key><string>SPRFST source</string>
            <key>UTTypeConformsTo</key><array><string>public.source-code</string></array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key><array><string>spf</string></array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
PLIST

# --------------------------------------------------------- resources
step "bundling the compiler and the library"
cp build/bin/sprfst "$APP/Contents/Resources/sprfst"
chmod +x "$APP/Contents/Resources/sprfst"
cp -R std        "$APP/Contents/Resources/std"
cp -R examples   "$APP/Contents/Resources/examples"
[ -d guidebook ] && cp -R guidebook "$APP/Contents/Resources/guidebook"
[ -d docs ]      && cp -R docs      "$APP/Contents/Resources/docs"
cp README.md     "$APP/Contents/Resources/README.md" 2>/dev/null || true

if [ "$STAGE_ONLY" = 1 ]; then
    cat > "$DIST/STAGING.txt" <<TXT
This is a staged bundle, not an application.

It was laid out on $(uname -s), which cannot compile Swift for macOS, so
Contents/MacOS/SPRFSTStudio is missing and the bundle will not launch.
Everything else — Info.plist, the icon, the compiler, the standard
library, the examples and the guidebook — is exactly what the real
build puts there.

Build the real thing on a Mac:

    ./tools/build_macos_app.sh
    ./tools/make_dmg.sh
TXT
    echo
    amber "staged  $APP"
    echo "    $(find "$APP" -type f | wc -l | tr -d ' ') files, $(du -sh "$APP" | cut -f1)"
    echo "    no executable: see $DIST/STAGING.txt"
    echo
    exit 0
fi

# ------------------------------------------------------------- swift
step "compiling Studio (Swift, $ARCH)"
SOURCES=(ide/macos/Sources/*.swift)
swiftc \
    -target "${ARCH}-apple-macos12.0" \
    -O -whole-module-optimization \
    -framework AppKit -framework Foundation \
    -o "$APP/Contents/MacOS/SPRFSTStudio" \
    "${SOURCES[@]}"

# ------------------------------------------------------------- sign
step "signing (ad hoc)"
codesign --force --deep --sign - "$APP" 2>/dev/null \
    && echo "    signed ad hoc — Gatekeeper will still ask on first launch" \
    || echo "    could not sign; the app will still run after a right click → Open"

SIZE=$(du -sh "$APP" | cut -f1)
amber "built  $APP  ($SIZE)"
echo
echo "    open \"$APP\""
echo "    ./tools/make_dmg.sh        to build the disk image"
echo
