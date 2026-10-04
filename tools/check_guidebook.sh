#!/usr/bin/env bash
# =====================================================================
#  Extracts every ```sprfst block from the guidebook and compiles it,
#  so no chapter can drift away from the language.
# =====================================================================
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPRFST="$ROOT/build/bin/sprfst"
export SPRFST_HOME="$ROOT"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ -t 1 ]; then GREEN=$'\033[38;5;114m'; RED=$'\033[38;5;203m'; DIM=$'\033[2m'; OFF=$'\033[0m'
else GREEN=""; RED=""; DIM=""; OFF=""; fi

ok=0; bad=0
mode="${1:-run}"            # run | check

for chapter in "$ROOT"/guidebook/*.md; do
    name=$(basename "$chapter")
    block=0
    python3 - "$chapter" "$TMP" <<'PY'
import sys, os, re
path, tmp = sys.argv[1], sys.argv[2]
text = open(path).read()
stem = os.path.basename(path).replace('.md', '')
blocks = re.findall(r"```sprfst\n(.*?)```", text, re.S)
for i, code in enumerate(blocks):
    with open(f"{tmp}/{stem}-{i:02d}.spf", "w") as f:
        f.write(code)
PY
    for file in "$TMP/${name%.md}"-*.spf; do
        [ -e "$file" ] || continue
        block=$((block + 1))
        if out=$(cd "$TMP" && SPRFST_UI=none timeout 30 "$SPRFST" "$mode" "$file" 2>&1 >/dev/null); then
            ok=$((ok + 1))
        else
            bad=$((bad + 1))
            printf "  ${RED}FAIL${OFF} %s block %d\n" "$name" "$block"
            printf "${DIM}%s${OFF}\n" "$(printf '%s' "$out" | head -8)"
        fi
    done
done

printf "\n  ${GREEN}%d blocks ran${OFF}, %s%d failed${OFF}\n\n" "$ok" "$([ $bad -gt 0 ] && printf '%s' "$RED" || printf '%s' "$DIM")" "$bad"
[ "$bad" -eq 0 ] || exit 1
