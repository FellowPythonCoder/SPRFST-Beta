#!/usr/bin/env bash
# =====================================================================
#  The browser, against a real server.
#
#  Starts browser/tests/fixture.spf — a page of the modern web, with
#  adverts, trackers, a consent wall and a chat widget — reads it with
#  the engine, and checks that what came back is the article and not
#  the rubbish around it.
#
#      ./tools/browser_live.sh
#
#  Nothing here touches the network: the fixture is served from this
#  machine, on a port nobody else is using.
# =====================================================================
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SPRFST="$ROOT/build/bin/sprfst"
PORT="${SPRFST_FIXTURE_PORT:-8137}"
BASE="http://127.0.0.1:$PORT"

if [ -t 1 ]; then
    AMBER=$'\033[38;5;214m'; GREEN=$'\033[38;5;114m'; RED=$'\033[38;5;203m'; OFF=$'\033[0m'
else
    AMBER=""; GREEN=""; RED=""; OFF=""
fi

[ -x "$SPRFST" ] || { echo "  build the compiler first:  make"; exit 1; }

pass=0
fail=0
check() {   # check <name> <haystack file> <needle>
    if grep -qF -- "$3" "$2"; then
        printf '  %spass%s  %s\n' "$GREEN" "$OFF" "$1"
        pass=$((pass + 1))
    else
        printf '  %sfail%s  %s\n' "$RED" "$OFF" "$1"
        printf '        expected to find: %s\n' "$3"
        fail=$((fail + 1))
    fi
}

absent() { # absent <name> <haystack file> <needle>
    if grep -qF -- "$3" "$2"; then
        printf '  %sfail%s  %s\n' "$RED" "$OFF" "$1"
        printf '        should not be there: %s\n' "$3"
        fail=$((fail + 1))
    else
        printf '  %spass%s  %s\n' "$GREEN" "$OFF" "$1"
        pass=$((pass + 1))
    fi
}

printf '\n%sthe browser, against a server%s\n\n' "$AMBER" "$OFF"

"$SPRFST" run browser/tests/fixture.spf -- "$PORT" >/dev/null 2>&1 &
FIXTURE=$!
trap 'kill $FIXTURE 2>/dev/null' EXIT

# wait for the port, up to three seconds
ready=0
for _ in $(seq 1 30); do
    if "$SPRFST" run browser/engine/main.spf -- --plain "$BASE/" 2>/dev/null | grep -q "Daily Fixture"; then
        ready=1; break
    fi
    sleep 0.1
done
[ "$ready" = 1 ] || { echo "  the fixture server did not start"; exit 1; }

OUT=$(mktemp)
SPRFST_BROWSER_HOME="$ROOT/browser/privacy-rules" "$SPRFST" run browser/engine/main.spf -- \
    --plain "$BASE/" > "$OUT" 2>&1

check   "the article is read"            "$OUT" "Paragraph 14."
check   "the headline is the title"      "$OUT" "Nine ways to read the news"
check   "links are kept"                 "$OUT" "First point"
check   "the quote is laid out"          "$OUT" "A page should be a page"
absent  "the consent wall is gone"       "$OUT" "1,431 partners"
absent  "the advert is gone"             "$OUT" "buy a boat"
absent  "the content farm is gone"       "$OUT" "Promoted stories"
absent  "the chat widget is gone"        "$OUT" "Chat with us"
absent  "no script is ever text"         "$OUT" "var x = 1"
check   "five requests were stopped"     "$OUT" "5 blocked"
check   "four elements were hidden"      "$OUT" "4 hidden"

READER=$(mktemp)
SPRFST_BROWSER_HOME="$ROOT/browser/privacy-rules" "$SPRFST" run browser/engine/main.spf -- \
    --plain --reader "$BASE/" > "$READER" 2>&1
check   "the lens keeps the article"     "$READER" "Paragraph 9."
absent  "the lens drops the navigation"  "$READER" "Weather"
absent  "the lens drops the sidebar"     "$READER" "Most read"

SERVE=$(mktemp)
printf '{"do":"open","tab":"0","url":"%s/"}\n{"do":"open","tab":"0","url":"%s/moved"}\n{"do":"back","tab":"0"}\n{"do":"bye"}\n' \
    "$BASE" "$BASE" | SPRFST_BROWSER_HOME="$ROOT/browser/privacy-rules" \
    "$SPRFST" run browser/engine/main.spf -- --serve > "$SERVE" 2>&1
check   "the service answers"            "$SERVE" '"service":"sprfst-browser"'
check   "a redirect is followed"         "$SERVE" '"status":200'
check   "going back is from the store"   "$SERVE" '"cached":true'
check   "the display list has positions" "$SERVE" '"k":"text"'

NOTFOUND=$(mktemp)
SPRFST_BROWSER_HOME="$ROOT/browser/privacy-rules" "$SPRFST" run browser/engine/main.spf -- \
    --plain "$BASE/nowhere" > "$NOTFOUND" 2>&1
check   "a 404 is still a page"          "$NOTFOUND" "404"

rm -f "$OUT" "$READER" "$SERVE" "$NOTFOUND"
kill $FIXTURE 2>/dev/null
trap - EXIT

printf '\n  %s%d passed%s, %d failed\n\n' "$GREEN" "$pass" "$OFF" "$fail"
[ "$fail" = 0 ]
