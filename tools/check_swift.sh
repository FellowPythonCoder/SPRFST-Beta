#!/usr/bin/env bash
# =====================================================================
#  Static checks on the Swift sources of both applications.
#
#  Swift and AppKit only exist on a Mac, so on any other machine this
#  is the most that can be said about the editor's code: that the
#  braces balance, that every #selector points at an @objc method that
#  exists, that AppKit subclasses have the initialisers AppKit insists
#  on, and that there is exactly one program entry point.
#
#  It is not a compiler. On a Mac, the real check is:
#      ./tools/build_macos_app.sh
# =====================================================================
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v swiftc >/dev/null 2>&1; then
    echo "  swiftc is available — the real build is ./tools/build_macos_app.sh"
fi

# Two applications share one kit: Theme, Chrome and the logo.
KIT="$ROOT/ide/macos/Sources/Theme.swift $ROOT/ide/macos/Sources/Chrome.swift $ROOT/ide/macos/Sources/LogoView.swift"

python3 - "Studio|$ROOT/ide/macos/Sources" "Browser|$ROOT/browser/mac-app/Sources|$KIT" <<'PY'
import re, sys, glob, os

def gather(spec):
    """name|folder[|extra files] -> (name, folder, [paths])"""
    bits = spec.split("|")
    name, folder = bits[0], bits[1]
    files = sorted(glob.glob(os.path.join(folder, "*.swift")))
    for extra in bits[2:]:
        files += [f for f in extra.split() if f]
    return name, folder, files

products = [gather(a) for a in sys.argv[1:]]
problems = []

def strip(code):
    """Remove strings and comments so brackets can be counted."""
    out, i, n, state = [], 0, len(code), None
    while i < n:
        c = code[i]
        if state is None:
            if code[i:i+3] == '"""': state = '"""'; i += 3; continue
            if c == '"': state = '"'; i += 1; continue
            if code[i:i+2] == '//':
                j = code.find('\n', i); i = n if j < 0 else j; continue
            if code[i:i+2] == '/*':
                j = code.find('*/', i); i = n if j < 0 else j + 2; continue
            out.append(c); i += 1
        elif state == '"':
            if c == '\\': i += 2; continue
            if c == '"': state = None
            i += 1
        else:
            if code[i:i+3] == '"""': state = None; i += 3; continue
            i += 1
    return ''.join(out)

def check(name, folder, files):
  src = {f: open(f).read() for f in files}
  if not files:
    problems.append(f"{name}: no Swift sources found"); return
  # brackets
  for f, code in src.items():
    s = strip(code)
    for a, b in (('{', '}'), ('(', ')'), ('[', ']')):
        if s.count(a) != s.count(b):
            problems.append(f"{os.path.basename(f)}: {a}{b} unbalanced ({s.count(a)} / {s.count(b)})")

  # #selector targets
  methods = {}
  for f, code in src.items():
    for m in re.finditer(r'(@objc\s+)?(?:private\s+|public\s+|internal\s+|final\s+|static\s+|class\s+)*func\s+(\w+)', code):
        methods.setdefault(m.group(2), []).append(bool(m.group(1)))
  APPKIT = ('NSApplication', 'NSText', 'NSWindow', 'NSResponder', 'NSMenu', 'NSDocument', 'NSView')
  for f, code in src.items():
    for m in re.finditer(r'#selector\(\s*([\w.]+)', code):
        ref = m.group(1)
        if ref.split('.')[0] in APPKIT:        # provided by the framework
            continue
        nm = ref.split('.')[-1]
        if nm not in methods:
            problems.append(f"{os.path.basename(f)}: #selector({ref}) has no such method")
        elif not any(methods[nm]):
            problems.append(f"{os.path.basename(f)}: #selector({ref}) is not marked @objc")

  # AppKit subclasses that override init(frame:) must also have init?(coder:)
  for f, code in src.items():
    for cls in re.finditer(r'(?:final\s+)?class\s+(\w+)\s*:\s*([^\{]+)\{', code):
        cname, bases = cls.group(1), cls.group(2)
        if not re.search(r'NS(View|Button|RulerView|TableRowView|Window)', bases):
            continue
        rest = code[cls.end():]
        nxt = re.search(r'\n(?:final )?class ', rest)
        body = rest[:nxt.start()] if nxt else rest
        if 'override init(frame' in body and 'init?(coder' not in body:
            problems.append(f"{os.path.basename(f)}: {cname} needs init?(coder:)")
        # NSRulerView is the odd one out: it redeclares initWithCoder: as
        # non-failable, so a subclass must override init(coder:), not
        # init?(coder:).  swiftc rejects the failable form outright.
        if 'NSRulerView' in bases and 'init?(coder' in body:
            problems.append(f"{os.path.basename(f)}: {cname} subclasses NSRulerView, "
                            "so init(coder:) must not be failable")

  # exactly one entry point
  entries = [os.path.basename(f) for f in files if '@main' in src[f]]
  if os.path.join(folder, 'main.swift') not in files:
    problems.append(f"{name}: there is no main.swift")
  if entries:
    problems.append(f"{name}: @main in {entries} clashes with main.swift")

  count = sum(len(c.splitlines()) for c in src.values())
  print(f"  {name}: {len(files)} Swift files, {count} lines")

for name, folder, files in products:
    check(name, folder, files)

if problems:
    for p in problems: print("  " + p)
    print(f"\n  {len(problems)} problem(s)\n")
    raise SystemExit(1)
print("  brackets, selectors and entry points all check out")
print("  (a Mac with swiftc is still the only real compile)")
PY
