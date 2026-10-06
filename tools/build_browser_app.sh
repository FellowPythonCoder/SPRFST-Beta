#!/usr/bin/env bash
# =====================================================================
#  Builds "SPRFST Browser.app" for Apple Silicon.
#
#      ./tools/build_browser_app.sh            full build (needs macOS)
#      ./tools/build_browser_app.sh --install  build, install, open it
#      ./tools/build_browser_app.sh --stage    lay the bundle out only
#      ./tools/build_browser_app.sh --skip-tests   build unverified
#
#  The bundle carries the engine — browser/src/*.spf — and the sprfst
#  interpreter that runs it. The window is Swift and AppKit; every
#  decision about a page is taken in SPRFST.
# =====================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="SPRFST Browser"
BUNDLE_ID="ai.sprfst.browser"
EXECUTABLE="SPRFSTBrowser"
VERSION="$(grep -o '"[0-9][^"]*"' compiler/include/sprfst/common.h | head -1 | tr -d '"')"
ARCH="${SPRFST_ARCH:-arm64}"
STAGE_ONLY=0
SKIP_TESTS=0
INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --stage)       STAGE_ONLY=1 ;;
        --skip-tests)  SKIP_TESTS=1 ;;
        --install)     INSTALL=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

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

amber "SPRFST Browser $VERSION  ($ARCH)$([ "$STAGE_ONLY" = 1 ] && echo '  — staging only')"

# ----------------------------------------------------------- compiler
step "building the interpreter"
make -j"$( (command -v sysctl >/dev/null && sysctl -n hw.ncpu) || nproc || echo 4)" >/dev/null
[ -x build/bin/sprfst ] || die "the compiler did not build"

step "testing the language and the engine"
if [ "$SKIP_TESTS" = 1 ]; then
    printf '    %s\n' "skipped by --skip-tests; you are packaging an unverified build"
else
    if ! language_log=$(./tests/run_tests.sh 2>&1); then
        # Keep the detail printed by the test runner.  Filtering to only the
        # FAIL line hid the useful compiler/runtime error on macOS, leaving
        # people with a failure name but no clue what to repair.
        printf '%s\n' "$language_log" | awk '
            /FAIL/ { print; remaining = 4; next }
            remaining > 0 { print; remaining-- }
        '
        die "the language tests failed — not packaging a broken build"
    fi
    printf '    %s\n' "$(printf '%s' "$language_log" | grep -oE '[0-9]+ passed[^0-9]*[0-9]+ failed' | tail -1)"
    if ! engine_log=$(cd browser && "$ROOT/build/bin/sprfst" test 2>&1); then
        printf '%s\n' "$engine_log" | grep -E "fail" | head -20
        die "the browser's own tests failed"
    fi
    printf '    %s\n' "$(printf '%s' "$engine_log" | grep -oE '[0-9]+ passed[^0-9]*[0-9]+ failed' | tail -1)"
fi

step "checking the window's sources"
if ! swift_log=$(./tools/check_swift.sh 2>&1); then
    printf '%s\n' "$swift_log" | head -20
    die "the Swift sources did not pass their static checks"
fi

# -------------------------------------------------------------- icons
step "drawing the icon with SPRFST itself"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
SPRFST_HOME="$ROOT" ./build/bin/sprfst run assets/logo/make_browser_icons.spf >/dev/null
SPRFST_HOME="$ROOT" ./build/bin/sprfst run assets/logo/make_browser_icns.spf -- \
    "$APP/Contents/Resources/SPRFSTBrowser.icns" >/dev/null

# ------------------------------------------------------------- bundle
step "laying out the bundle"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$EXECUTABLE</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>SPRFSTBrowser</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSRequiresAquaSystemAppearance</key><false/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>Web page</string>
            <key>CFBundleURLSchemes</key>
            <array><string>http</string><string>https</string></array>
            <key>LSHandlerRank</key><string>Alternate</string>
        </dict>
        <dict>
            <key>CFBundleURLName</key><string>SPRFST page</string>
            <key>CFBundleURLSchemes</key><array><string>sprfst</string></array>
            <key>LSHandlerRank</key><string>Owner</string>
        </dict>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key><true/>
    </dict>
</dict>
</plist>
PLIST

# ---------------------------------------------------------- resources
step "bundling the engine"
mkdir -p "$APP/Contents/Resources/bin" "$APP/Contents/Resources/engine"
cp build/bin/sprfst "$APP/Contents/Resources/bin/sprfst"
chmod +x "$APP/Contents/Resources/bin/sprfst"
cp browser/src/*.spf        "$APP/Contents/Resources/engine/"
cp browser/rules/*.rules    "$APP/Contents/Resources/engine/"
cp -R std                   "$APP/Contents/Resources/std"
cp browser/README.md        "$APP/Contents/Resources/README.md" 2>/dev/null || true
if [ -d browser/docs ]; then
    mkdir -p "$APP/Contents/Resources/docs"
    cp browser/docs/*.md "$APP/Contents/Resources/docs/"
fi
printf '    %s engine modules, %s block rules\n' \
    "$(ls browser/src/*.spf | wc -l | tr -d ' ')" \
    "$(grep -cvE '^\s*(~~|!|$)' browser/rules/shield.rules | tr -d ' ')"

if [ "$STAGE_ONLY" = 1 ]; then
    cat > "$DIST/STAGING-browser.txt" <<TXT
This is a staged bundle, not an application.

It was laid out on $(uname -s), which cannot compile Swift for macOS, so
Contents/MacOS/$EXECUTABLE is missing and the bundle will not launch.
Everything else — Info.plist, the icon, the engine, the interpreter and
the block rules — is exactly what the real build puts there.

Build the real thing on a Mac:

    ./tools/build_browser_app.sh --install
TXT
    echo
    amber "staged  $APP"
    echo "    $(find "$APP" -type f | wc -l | tr -d ' ') files, $(du -sh "$APP" | cut -f1)"
    echo
    exit 0
fi

# --------------------------------------------------------------- swift
step "compiling the window (Swift, $ARCH)"
SOURCES=(browser/macos/Sources/*.swift
         ide/macos/Sources/Theme.swift
         ide/macos/Sources/Chrome.swift
         ide/macos/Sources/LogoView.swift)
swiftc \
    -target "${ARCH}-apple-macos12.0" \
    -O -whole-module-optimization \
    -framework AppKit -framework Foundation \
    -o "$APP/Contents/MacOS/$EXECUTABLE" \
    "${SOURCES[@]}" || die "swiftc could not build the browser — the errors above are the first real compile of that code"

# ---------------------------------------------------------------- sign
step "signing (ad hoc)"
codesign --force --deep --sign - "$APP" 2>/dev/null \
    && echo "    signed ad hoc — Gatekeeper will still ask on first launch" \
    || echo "    could not sign; the app will still run after a right click → Open"

SIZE=$(du -sh "$APP" | cut -f1)
amber "built  $APP  ($SIZE)"

# ------------------------------------------------------------- install
if [ "$INSTALL" = 1 ]; then
    step "installing"
    TARGET="/Applications"
    if [ ! -w "$TARGET" ]; then
        TARGET="$HOME/Applications"
        mkdir -p "$TARGET"
        echo "    /Applications is not writable, using $TARGET"
    fi
    osascript -e 'tell application "SPRFST Browser" to quit' >/dev/null 2>&1 || true
    sleep 0.4
    rm -rf "$TARGET/$APP_NAME.app"
    cp -R "$APP" "$TARGET/" || die "could not copy the app into $TARGET"
    xattr -dr com.apple.quarantine "$TARGET/$APP_NAME.app" 2>/dev/null || true
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "$TARGET/$APP_NAME.app" >/dev/null 2>&1 || true
    echo "    $TARGET/$APP_NAME.app"
    open "$TARGET/$APP_NAME.app"
    echo
    amber "SPRFST Browser is open."
    echo
    exit 0
fi

echo
echo "    ./tools/build_browser_app.sh --install   put it in /Applications and open it"
echo "    ./tools/make_browser_dmg.sh              build the disk image"
echo
