#!/usr/bin/env bash
# =====================================================================
#  Builds "SPRFST Tour.app" for Apple Silicon.
#
#      ./tools/build_tour_app.sh            full build (needs macOS)
#      ./tools/build_tour_app.sh --install  build, install, open it
#      ./tools/build_tour_app.sh --stage    lay the bundle out only
#      ./tools/build_tour_app.sh --skip-tests   build unverified
#
#  The bundle carries the lessons — learn/tour.spf and learn/lessons.spf
#  — and the sprfst interpreter that runs them. The window is Swift and
#  AppKit; every lesson, every check and every point is decided in
#  SPRFST, so the window and the terminal tour cannot disagree.
# =====================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="SPRFST Tour"
BUNDLE_ID="ai.sprfst.tour"
EXECUTABLE="SPRFSTTour"
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

amber "SPRFST Tour $VERSION  ($ARCH)$([ "$STAGE_ONLY" = 1 ] && echo '  — staging only')"

# ----------------------------------------------------------- compiler
step "building the interpreter"
make -j"$( (command -v sysctl >/dev/null && sysctl -n hw.ncpu) || nproc || echo 4)" >/dev/null
[ -x build/bin/sprfst ] || die "the compiler did not build"

step "testing the language and every lesson"
if [ "$SKIP_TESTS" = 1 ]; then
    printf '    %s\n' "skipped by --skip-tests; you are packaging an unverified build"
else
    if ! language_log=$(./tests/run_tests.sh 2>&1); then
        printf '%s\n' "$language_log" | grep -E "FAIL|failed" | head -20
        die "the language tests failed — not packaging a broken build"
    fi
    printf '    %s\n' "$(printf '%s' "$language_log" | grep -oE '[0-9]+ passed[^0-9]*[0-9]+ failed' | tail -1)"
    if ! lesson_log=$(./build/bin/sprfst run learn/tour.spf -- --verify 2>&1); then
        printf '%s\n' "$lesson_log" | grep -E "FAIL" | head -20
        die "a lesson no longer produces the answer it promises"
    fi
    printf '    %s\n' "$(printf '%s' "$lesson_log" | grep -oE '[0-9]+ passed[^0-9]*[0-9]+ failed' | tail -1) lessons"
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
SPRFST_HOME="$ROOT" ./build/bin/sprfst run assets/logo/make_icns.spf -- \
    "$APP/Contents/Resources/SPRFSTTour.icns" >/dev/null

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
    <key>CFBundleIconFile</key><string>SPRFSTTour</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSRequiresAquaSystemAppearance</key><false/>
    <key>NSSupportsAutomaticTermination</key><false/>
</dict>
</plist>
PLIST

# ---------------------------------------------------------- resources
step "bundling the lessons"
mkdir -p "$APP/Contents/Resources/bin" "$APP/Contents/Resources/lessons"
cp build/bin/sprfst "$APP/Contents/Resources/bin/sprfst"
chmod +x "$APP/Contents/Resources/bin/sprfst"
cp learn/*.spf              "$APP/Contents/Resources/lessons/"
cp -R std                   "$APP/Contents/Resources/std"
printf '    %s lessons\n' \
    "$(grep -c 'out.push(Lesson {' learn/lessons.spf | tr -d ' ')"

if [ "$STAGE_ONLY" = 1 ]; then
    cat > "$DIST/STAGING-tour.txt" <<TXT
This is a staged bundle, not an application.

It was laid out on $(uname -s), which cannot compile Swift for macOS, so
Contents/MacOS/$EXECUTABLE is missing and the bundle will not launch.
Everything else — Info.plist, the icon, the lessons and the interpreter
— is exactly what the real build puts there.

Build the real thing on a Mac:

    ./tools/build_tour_app.sh --install
TXT
    echo
    amber "staged  $APP"
    echo "    $(find "$APP" -type f | wc -l | tr -d ' ') files, $(du -sh "$APP" | cut -f1)"
    echo
    exit 0
fi

# --------------------------------------------------------------- swift
step "compiling the window (Swift, $ARCH)"
SOURCES=(learn/macos/Sources/*.swift
         ide/macos/Sources/Theme.swift
         ide/macos/Sources/Chrome.swift
         ide/macos/Sources/LogoView.swift)
swiftc \
    -target "${ARCH}-apple-macos12.0" \
    -O -whole-module-optimization \
    -framework AppKit -framework Foundation \
    -o "$APP/Contents/MacOS/$EXECUTABLE" \
    "${SOURCES[@]}" || die "swiftc could not build the tour — the errors above are the first real compile of that code"

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
    osascript -e 'tell application "SPRFST Tour" to quit' >/dev/null 2>&1 || true
    sleep 0.4
    rm -rf "$TARGET/$APP_NAME.app"
    cp -R "$APP" "$TARGET/" || die "could not copy the app into $TARGET"
    xattr -dr com.apple.quarantine "$TARGET/$APP_NAME.app" 2>/dev/null || true
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "$TARGET/$APP_NAME.app" >/dev/null 2>&1 || true
    echo "    $TARGET/$APP_NAME.app"
    open "$TARGET/$APP_NAME.app"
    echo
    amber "SPRFST Tour is open — lesson one is waiting."
    echo
    exit 0
fi

echo
echo "    ./tools/build_tour_app.sh --install   put it in /Applications and open it"
echo "    ./build/bin/sprfst run learn/tour.spf    the same lessons in a terminal"
echo
