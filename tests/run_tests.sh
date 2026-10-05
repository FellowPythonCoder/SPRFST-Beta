#!/usr/bin/env bash
# =====================================================================
#  SPRFST test runner
#  Checks the toolchain itself: the language suite, every example, and
#  the command line verbs.  Exits non-zero if anything regresses.
# =====================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPRFST="$ROOT/build/bin/sprfst"
export SPRFST_HOME="$ROOT"

if [ ! -x "$SPRFST" ]; then
    echo "  build the compiler first:  make"
    exit 1
fi

if [ -t 1 ]; then
    AMBER=$'\033[38;5;214m'; GREEN=$'\033[38;5;114m'; RED=$'\033[38;5;203m'
    DIM=$'\033[2m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
else
    AMBER=""; GREEN=""; RED=""; DIM=""; BOLD=""; OFF=""
fi

# BSD grep refuses to match inside data that is not valid text in the
# current locale, and a PNG header starts with the byte 0x89.  Ask every
# tool for bytes.
export LC_ALL=C

# the first bytes of a file as hex — od is the same program everywhere,
# unlike grep on binary input, and unlike wc it needs no whitespace nursing
magic() {   # magic <file> <count>
    od -An -tx1 -N "$2" "$1" 2>/dev/null | tr -d ' \n'
}

# BSD wc pads its answer with spaces; arithmetic and printed sizes both hate that
size_of() { wc -c < "$1" | tr -d '[:space:]'; }
count_of() { wc -l | tr -d '[:space:]'; }

# macOS has no timeout(1), so bring our own: run a command, kill it if it
# overstays.  Used so one hung example cannot hang the whole run.
limit() {   # limit <seconds> <command...>
    local secs="$1"; shift
    if [ -z "${SPRFST_PORTABLE_LIMIT:-}" ]; then
        if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"; return $?; fi
        if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return $?; fi
    fi
    "$@" &
    local job=$!
    { sleep "$secs"; kill -9 "$job" 2>/dev/null; } >/dev/null 2>&1 &
    local watch=$!
    wait "$job"; local code=$?
    kill "$watch" 2>/dev/null
    wait "$watch" 2>/dev/null
    return $code
}

pass=0
fail=0
started=$(date +%s)

report() {   # report <name> <ok|no> [detail]
    if [ "$2" = "ok" ]; then
        pass=$((pass + 1))
        printf "  ${GREEN}pass${OFF}  %s\n" "$1"
    else
        fail=$((fail + 1))
        printf "  ${RED}FAIL${OFF}  %s\n" "$1"
        [ $# -ge 3 ] && printf "        ${DIM}%s${OFF}\n" "$3"
    fi
}

printf "\n  ${BOLD}${AMBER}SPRFST${OFF} test run  ${DIM}%s${OFF}\n\n" "$($SPRFST version)"

# ---------------------------------------------------------------- suite
printf "  ${DIM}language suite${OFF}\n"
out=$("$SPRFST" test "$ROOT" 2>&1)
if printf '%s' "$out" | grep -q "0 failed"; then
    n=$(printf '%s' "$out" | grep -oE '[0-9]+ passed' | head -1)
    report "language suite ($n)" ok
else
    report "language suite" no "$(printf '%s' "$out" | tail -5)"
fi

# ------------------------------------------------------------- examples
printf "\n  ${DIM}examples${OFF}\n"
for file in "$ROOT"/examples/*.spf; do
    name=$(basename "$file")
    case "$name" in
        18-gui-counter.spf|19-web-server.spf)
            # these two wait for input or a socket: type check only
            if err=$("$SPRFST" check "$file" 2>&1); then
                report "$name ${DIM}(checked)${OFF}" ok
            else
                report "$name" no "$(printf '%s' "$err" | head -4)"
            fi
            continue
            ;;
    esac
    if err=$(cd "$ROOT" && SPRFST_UI=none limit 60 "$SPRFST" run "$file" 2>&1 >/dev/null); then
        report "$name" ok
    else
        report "$name" no "$(printf '%s' "$err" | head -4)"
    fi
done

# ------------------------------------------------------------------ cli
printf "\n  ${DIM}command line${OFF}\n"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

(cd "$tmp" && "$SPRFST" new demo >/dev/null 2>&1)
[ -f "$tmp/demo/src/main.spf" ] && report "sprfst new" ok || report "sprfst new" no "no project created"

(cd "$tmp/demo" && "$SPRFST" run . >/dev/null 2>&1) && report "sprfst run" ok || report "sprfst run" no
(cd "$tmp/demo" && "$SPRFST" check . >/dev/null 2>&1) && report "sprfst check" ok || report "sprfst check" no
(cd "$tmp/demo" && "$SPRFST" build . >/dev/null 2>&1) && [ -f "$tmp/demo/build/program.spir" ] \
    && report "sprfst build" ok || report "sprfst build" no
(cd "$tmp/demo" && "$SPRFST" test . 2>&1 | grep -q "1 passed") && report "sprfst test" ok || report "sprfst test" no
(cd "$tmp/demo" && "$SPRFST" docs . >/dev/null 2>&1) && [ -f "$tmp/demo/docs/index.md" ] \
    && report "sprfst docs" ok || report "sprfst docs" no
(cd "$tmp/demo" && "$SPRFST" lint . >/dev/null 2>&1) && report "sprfst lint" ok || report "sprfst lint" no

printf 'fn  main( ){\nlet x=[1,2]\n}\n' > "$tmp/demo/src/messy.spf"
(cd "$tmp/demo" && "$SPRFST" fmt src/messy.spf >/dev/null 2>&1)
if grep -q "let x = \[1, 2\]" "$tmp/demo/src/messy.spf"; then report "sprfst fmt" ok; else report "sprfst fmt" no; fi

(cd "$tmp/demo" && "$SPRFST" clean >/dev/null 2>&1) && [ ! -d "$tmp/demo/build" ] \
    && report "sprfst clean" ok || report "sprfst clean" no

# forge: add a local package and verify the lockfile digest
mkdir -p "$tmp/pkg/src"
printf '[package]\nname = "greet"\nversion = "1.0.0"\nentry = "src/greet.spf"\n' > "$tmp/pkg/project.sprfst"
printf 'module greet\npub fn hello() -> Text => "hi from the package"\n' > "$tmp/pkg/src/greet.spf"
(cd "$tmp/demo" && "$SPRFST" add greet --path="$tmp/pkg" >/dev/null 2>&1)
[ -f "$tmp/demo/forge.lock" ] && [ -d "$tmp/demo/packages/greet" ] \
    && report "forge add" ok || report "forge add" no
(cd "$tmp/demo" && "$SPRFST" install 2>&1 | grep -q installed) && report "forge install (digest verified)" ok \
    || report "forge install" no
(cd "$tmp/demo" && "$SPRFST" remove greet >/dev/null 2>&1) && [ ! -d "$tmp/demo/packages/greet" ] \
    && report "forge remove" ok || report "forge remove" no

# studio language service
svc=$(printf 'version\noutline %s\nbye\n' "$ROOT/examples/01-hello.spf" | "$SPRFST" studio 2>/dev/null)
printf '%s' "$svc" | grep -q '"service":"sprfst-studio"' && report "studio handshake" ok || report "studio handshake" no
printf '%s' "$svc" | grep -q '"name":"main"' && report "studio outline" ok || report "studio outline" no

diag=$(printf 'let x: Int = "text"\nfn main() { }\n' > "$tmp/bad.spf"; "$SPRFST" check "$tmp/bad.spf" --json 2>/dev/null)
printf '%s' "$diag" | grep -q 'E0' && report "json diagnostics" ok || report "json diagnostics" no

# the debugger stops where it is told
dbg=$(printf 'b 5\nc\nv\nq\n' | "$SPRFST" debug "$ROOT/examples/02-variables.spf" 2>&1)
printf '%s' "$dbg" | grep -q "breakpoint" && report "debugger breakpoint" ok || report "debugger breakpoint" no

# a package added by Forge can actually be imported and run
printf 'use std.io\nuse greet\nfn main() { io.say(greet.hello()) }\n' > "$tmp/demo/src/main.spf"
(cd "$tmp/demo" && "$SPRFST" add greet --path="$tmp/pkg" >/dev/null 2>&1)
if (cd "$tmp/demo" && "$SPRFST" run . 2>&1 | grep -q "hi from the package"); then
    report "use a Forge package" ok
else
    report "use a Forge package" no "$(cd "$tmp/demo" && "$SPRFST" run . 2>&1 | head -4)"
fi
(cd "$tmp/demo" && "$SPRFST" remove greet >/dev/null 2>&1)

# ----------------------------------------------------------- language
printf "\n  ${DIM}language details${OFF}\n"

# a closure capturing a value used inside a block body
cat > "$tmp/capture.spf" <<'SPF'
use std.io
fn call(f: fn() -> Nil) { f() }
fn main() {
    let a = 10
    let b = 20
    call(fn() => { io.say("{a} {b}") })
}
SPF
out=$("$SPRFST" run "$tmp/capture.spf" 2>&1)
[ "$out" = "10 20" ] && report "closures capture inside blocks" ok \
    || report "closures capture inside blocks" no "got: $out"

# a UI event that carries its value back into state
cat > "$tmp/ui.spf" <<'SPF'
app "Field" {
    var draft = ""
    var kept: [Text] = []
    window {
        title: "Field"
        field "Note" {
            value: draft
            on change(text) { draft = text }
        }
        button "Keep" {
            on click { kept.push(draft) }
        }
        list { items: kept }
    }
}
SPF
out=$(printf '1\nhello\n2\nq\n' | SPRFST_UI=term "$SPRFST" run "$tmp/ui.spf" 2>&1)
printf '%s' "$out" | grep -q -- "- hello" && report "ui event values reach state" ok \
    || report "ui event values reach state" no "$(printf '%s' "$out" | tail -3)"

# -O0 really turns the optimiser off
printf 'use std.io\nfn main() { io.say("{2 + 3 * 4}") }\n' > "$tmp/fold.spf"
o0=$(cd "$tmp" && "$SPRFST" build fold.spf -O0 2>&1 | grep -o 'folded [0-9]*')
o2=$(cd "$tmp" && "$SPRFST" build fold.spf -O2 2>&1 | grep -o 'folded [0-9]*')
[ "$o0" = "folded 0" ] && [ "$o2" != "folded 0" ] && report "optimiser levels ($o0 vs $o2)" ok \
    || report "optimiser levels" no "O0: $o0  O2: $o2"

# ------------------------------------------------------------ pictures
printf "\n  ${DIM}graphics and packaging${OFF}\n"

cat > "$tmp/png.spf" <<'SPF'
use std.io
use std.draw
fn main() {
    let c = draw.canvas(256, 256)
    draw.clear(c, draw.rgb(11, 11, 13))
    draw.circle(c, 128, 128, 90, draw.rgb(255, 161, 54))
    io.say("{draw.save_png(c, "shot.png")}")
}
SPF
(cd "$tmp" && "$SPRFST" run png.spf >/dev/null 2>&1)
if [ -f "$tmp/shot.png" ]; then
    size=$(size_of "$tmp/shot.png")
    if [ "$(magic "$tmp/shot.png" 8)" != "89504e470d0a1a0a" ]; then
        report "png written" no "the file does not start with the PNG signature"
    elif [ "$size" -ge 65536 ]; then
        report "png compression" no "${size} bytes for 256x256 — compression is not working"
    else
        report "png written and compressed (${size} bytes for 256x256)" ok
    fi
else
    report "png written" no "no file"
fi

# the macOS icon file, written by SPRFST itself
(cd "$ROOT" && "$SPRFST" run assets/logo/make_icns.spf -- "$tmp/SPRFST.icns" >/dev/null 2>&1)
if [ -f "$tmp/SPRFST.icns" ] && [ "$(magic "$tmp/SPRFST.icns" 4)" = "69636e73" ]; then
    report "icns icon generated ($(( $(size_of "$tmp/SPRFST.icns") / 1024 )) KB)" ok
else
    report "icns icon generated" no "no icns file"
fi

# a disk image, written and then read back by a parser that shares no code
img="$tmp/image"
mkdir -p "$img/Folder With A Long Name/inner"
printf 'first file\n' > "$img/Read me.txt"
head -c 5000 "$ROOT/README.md" > "$img/Folder With A Long Name/long.md"
printf 'deep\n' > "$img/Folder With A Long Name/inner/deep.txt"
(cd "$ROOT" && "$SPRFST" run tools/make_iso.spf -- "$img" "$tmp/out.dmg" "TEST IMAGE" >/dev/null 2>&1)
if [ -f "$tmp/out.dmg" ]; then
    if vi=$(cd "$ROOT" && "$SPRFST" run tools/verify_iso.spf -- "$tmp/out.dmg" "$img" 2>&1); then
        report "disk image ($(( $(size_of "$tmp/out.dmg") / 1024 )) KB, 3 files, read back and compared)" ok
    else
        report "disk image verifies" no "$(printf '%s' "$vi" | tail -4)"
    fi
    # the Finder looks for CD001 at this exact spot before it will mount anything
    if [ "$(dd if="$tmp/out.dmg" bs=1 skip=32769 count=5 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "4344303031" ]; then
        report "disk image is mountable (CD001 at 0x8001)" ok
    else
        report "disk image is mountable" no "no CD001 signature"
    fi
else
    report "disk image written" no "no file"
fi

# the formatter must never break a file, and must settle after one pass
fmtdir="$tmp/fmt"
mkdir -p "$fmtdir"
cp "$ROOT"/examples/*.spf "$ROOT"/std/*.spf "$ROOT"/tools/*.spf "$fmtdir/" 2>/dev/null
broke=0; moved=0; count=0; broken_files=""; moving_files=""
for f in "$fmtdir"/*.spf; do
    count=$((count + 1))
    (cd "$ROOT" && "$SPRFST" fmt "$f" >/dev/null 2>&1)
    if ! (cd "$ROOT" && "$SPRFST" check "$f" >/dev/null 2>&1); then
        broke=$((broke + 1))
        broken_files="$broken_files $(basename "$f")"
    fi
    cp "$f" "$f.once"
    (cd "$ROOT" && "$SPRFST" fmt "$f" >/dev/null 2>&1)
    if ! cmp -s "$f" "$f.once"; then
        moved=$((moved + 1))
        moving_files="$moving_files $(basename "$f")"
    fi
done
if [ "$broke" = 0 ] && [ "$moved" = 0 ]; then
    report "formatter round trip ($count files still compile, and settle in one pass)" ok
else
    detail="$broke files broken${broken_files:+:$broken_files}, $moved still moving${moving_files:+:$moving_files}"
    report "formatter round trip" no "$detail"
fi

# the guidebook as PDF, typeset and then read back
(cd "$ROOT" && "$SPRFST" run tools/make_pdf.spf -- "$tmp/pdf" >/dev/null 2>&1)
if [ -f "$tmp/pdf/SPRFST-Guidebook.pdf" ]; then
    chapters=$(ls "$tmp/pdf"/*.pdf | count_of)
    if vp=$(cd "$ROOT" && "$SPRFST" run tools/verify_pdf.spf -- "$tmp/pdf/SPRFST-Guidebook.pdf" 2>&1); then
        report "guidebook pdfs ($chapters files, $(printf '%s' "$vp" | grep -oE '[0-9]+ pages' | head -1), table checked)" ok
    else
        report "guidebook pdf verifies" no "$(printf '%s' "$vp" | tail -4)"
    fi
else
    report "guidebook pdf written" no "no file"
fi

# the Swift of both applications, as far as a machine with no Swift can tell
if sw=$("$ROOT/tools/check_swift.sh" 2>&1); then
    report "studio sources ($(printf '%s' "$sw" | grep -oE 'Studio: [0-9]+ Swift files' | grep -oE '[0-9]+ Swift files'))" ok
    report "browser sources ($(printf '%s' "$sw" | grep -oE 'Browser: [0-9]+ Swift files' | grep -oE '[0-9]+ Swift files'))" ok
else
    report "application sources" no "$(printf '%s' "$sw" | head -6)"
fi

# ------------------------------------------------------------- browser
printf "\n  ${DIM}browser${OFF}\n"
if err=$("$SPRFST" check "$ROOT/browser/src/main.spf" 2>&1); then
    report "engine checks ($(printf '%s' "$err" | grep -oE '[0-9]+ files'))" ok
else
    report "engine checks" no "$(printf '%s' "$err" | head -6)"
fi
bt=$(cd "$ROOT/browser" && "$SPRFST" test 2>&1)
if printf '%s' "$bt" | grep -q "0 failed"; then
    report "engine suite ($(printf '%s' "$bt" | grep -oE '[0-9]+ passed' | tail -1))" ok
else
    report "engine suite" no "$(printf '%s' "$bt" | grep -A 1 'fail ' | head -6)"
fi
bl=$(limit 120 "$ROOT/tools/browser_live.sh" 2>&1)
if printf '%s' "$bl" | grep -q "0 failed"; then
    report "browser against a server ($(printf '%s' "$bl" | grep -oE '[0-9]+ passed' | tail -1))" ok
else
    report "browser against a server" no "$(printf '%s' "$bl" | grep -B 1 'fail' | head -6)"
fi

for script in tools/build_macos_app.sh tools/make_dmg.sh tools/check_guidebook.sh tools/check_swift.sh \
              tools/build_browser_app.sh tools/make_browser_dmg.sh tools/browser_live.sh; do
    bash -n "$ROOT/$script" 2>/dev/null && report "$(basename "$script") parses" ok \
        || report "$(basename "$script") parses" no
done

# every guidebook chapter still compiles
gb=$("$ROOT/tools/check_guidebook.sh" 2>&1 | tail -3)
printf '%s' "$gb" | grep -q "0 failed" \
    && report "guidebook ($(printf '%s' "$gb" | grep -oE '[0-9]+ blocks ran'))" ok \
    || report "guidebook" no "$gb"

# ---------------------------------------------------------------- total
elapsed=$(( $(date +%s) - started ))
printf "\n  ${BOLD}%d passed${OFF}, %s%d failed${OFF}  ${DIM}%ds${OFF}\n\n" \
    "$pass" "$([ $fail -gt 0 ] && printf '%s' "$RED" || printf '%s' "$DIM")" "$fail" "$elapsed"
[ "$fail" -eq 0 ] || exit 1
