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
    if err=$(cd "$ROOT" && SPRFST_UI=none timeout 60 "$SPRFST" run "$file" 2>&1 >/dev/null); then
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

# ---------------------------------------------------------------- total
elapsed=$(( $(date +%s) - started ))
printf "\n  ${BOLD}%d passed${OFF}, %s%d failed${OFF}  ${DIM}%ds${OFF}\n\n" \
    "$pass" "$([ $fail -gt 0 ] && printf '%s' "$RED" || printf '%s' "$DIM")" "$fail" "$elapsed"
[ "$fail" -eq 0 ] || exit 1
