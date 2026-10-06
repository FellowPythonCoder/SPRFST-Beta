<div align="center">

<img src="assets/logo/png/sprfst-256.png" width="128" alt="SPRFST">

# SPRFST

**A new programming language, its toolchain, and a Mac editor to write it in.**

Deep black, warm amber, nothing you do not need.

</div>

---

SPRFST is a language built from scratch: its own lexer, parser, type
checker, intermediate representation, optimiser and runtime, written in
C. It is not a layer over Python, JavaScript, C++, Rust or Java, and it
does not transpile to anything. A program you write here is read,
checked and executed by the code in this repository.

It comes with a standard library, a package manager, a debugger, a
formatter, a linter, a documentation generator, a thirty chapter
guidebook, twenty one worked examples, and **SPRFST Studio** — a native
macOS editor for Apple Silicon.

```sprfst
use std.io

fn main() {
    let names = ["Ada", "Grace", "Alan"]
    for name in names {
        io.say("hello, {name}")
    }
}
```

```
$ sprfst run hello.spf
hello, Ada
hello, Grace
hello, Alan
```

## Build it

Needs a C compiler and `make`. Nothing else, and no network.

```sh
make
make test
./build/bin/sprfst run examples/01-hello.spf
```

`make` builds `build/bin/sprfst`; `make test` runs the 61 checks covering
language, examples, the CLI, the guidebook and the browser. The commands
are deliberately shown without trailing comments: zsh, the default shell
on macOS, passes an inline `#` to the command unless interactive comments
are enabled.

To use it from anywhere:

```sh
sudo make install
```

This installs `/usr/local/bin/sprfst` and
`/usr/local/lib/sprfst/std`.

On a Mac with the Xcode command line tools, one target builds the
editor, installs it and opens it:

```sh
make studio
make app
make dmg
make stage
```

These build, respectively, the installed Studio app, a staged app,
the Studio disk image, and a non-Mac staging layout.

And one builds the browser:

```sh
make browser
make browser-dmg
make browser-test
```

The browser targets build/install the app, create its disk image, and
run the engine's 30 offline tests followed by 19 fixture-server tests.

```sh
make pdf
```

This writes the 30 chapter PDFs and the complete guidebook to
`guidebook/pdf`.

The PDFs are typeset by `tools/make_pdf.spf`: it reads the Markdown,
measures every line with the real Helvetica and Courier metrics, and
writes PDF 1.4 by hand — objects, cross reference table, trailer, and
an outline so Preview lists the thirty chapters down the side. No
library, no LaTeX, no browser. `tools/verify_pdf.spf` reads the result
back and checks that every entry in the cross reference table lands on
the object it names and that every stream is as long as it claims.

`make dmg` works away from a Mac too. With no `swiftc` there is no
application to wrap, so instead of an empty bundle it writes
`dist/SPRFST-0.1.0-beta.dmg`: a real ISO 9660 image with Joliet names,
carrying the whole project and an installer that builds it on the Mac it
is opened on. The image writer is `tools/make_iso.spf` and the reader
that checks it, which shares no code with the writer, is
`tools/verify_iso.spf` — both written in SPRFST.

Every command, step by step, with the output of each one:
[RUNNING.md](RUNNING.md).

## The language in one page

```sprfst
use std.io
use std.math

~~ A comment. `~[ ... ]~` spans lines.

data Point { x: Num  y: Num }          ~~ plain record

object Circle {                         ~~ object with behaviour
    at: Point = Point { x: 0.0, y: 0.0 }
    radius: Num = 1.0

    fn area(self) -> Num => math.pi() * self.radius ** 2.0
    fn grow(self, by: Num) { self.radius = self.radius + by }
}

trait Shape { fn area(self) -> Num }    ~~ behaviour, implemented by name

enum Answer { Yes  No  Maybe(Text) }    ~~ variants may carry values

fn describe(a: Answer) -> Text {
    give match a {
        when Yes -> "yes"
        when No -> "no"
        when Maybe(why) -> "maybe, {why}"
    }
}

fn main() {
    var c = Circle { radius: 2.0 }
    c.grow(0.5)
    io.say("area {c.area()}")
    io.say(describe(Maybe("ask again")))

    let nums = [1, 2, 3, 4, 5]
    io.say("{nums.filter(fn(n) => n % 2 == 1).map(fn(n) => n * n)}")
    io.say("total {nums |> sum}")
}
```

What is different, and why:

| | |
| --- | --- |
| `give` instead of `return` | a function *gives* a value; `return` says nothing about direction |
| `and` `or` `not` | words, not punctuation |
| `~~` comments | never collides with division or URLs |
| `{holes}` in text | no format strings, no concatenation ceremony |
| `x.f()` works on anything | a method, or a free function `f(x)` — one way to call |
| `\|>` pipelines | `nums \|> sum` reads left to right |
| `fn(x) => x * 2` | one lambda form |
| no tuples, no semicolons | one way to group values: `data` |
| `Int / Int` gives `Num` | `7 / 2` is `3.5`, as everybody expects |
| `own` and `ref` | opt in single ownership, checked by the compiler |

The full tour is in [`guidebook/`](guidebook/) — thirty chapters, every
code block compiled and run by `tools/check_guidebook.sh`.

## The commands

```
sprfst run    <file|.>      compile and run
sprfst check  [path]        type check, no output
sprfst build  [path]        compile and write build artefacts
sprfst test   [path]        run every test and benchmark
sprfst fmt    [path]        format source in place
sprfst lint   [path]        report style and clarity problems
sprfst docs   [path]        write documentation to docs/
sprfst debug  <file>        run under the debugger
sprfst new    <name>        start a project
sprfst add    <pkg>         add a package with Forge
sprfst remove <pkg>         remove a package
sprfst install              fetch everything in project.sprfst
sprfst package              build a .forge archive
sprfst studio               the editor language service (JSON over stdin)
sprfst clean                delete build/
```

Options: `-O0`..`-O3`, `--json`, `--ir`, `--time`, `--quiet`,
`--no-color`, and `--` to pass the rest to the program.

## A project

```
project.sprfst     name, version, entry point, dependencies
forge.lock         what was installed, with SHA-256 digests
src/               your code
tests/             your tests
assets/            files your program loads
packages/          dependencies, copied in by Forge
build/             output, safe to delete
```

## What is in the box

| | |
| --- | --- |
| **Compiler** | lexer → parser → types → semantic analysis → SPIR → optimiser → runtime, with incremental module loading and debug line tables |
| **Diagnostics** | every error carries a code, the source line, an underline, what you gave against what was wanted, and suggested fixes |
| **Runtime** | register VM, tracing collector, closures, traits with dynamic dispatch, generics by erasure |
| **Standard library** | 246 native functions across `io math fs path time rand sys json csv hash net http thread task db tensor ui draw`, plus `core collections testing ai` written in SPRFST in [`std/`](std/) |
| **Concurrency** | threads, tasks, futures, channels, locks and atomics |
| **Database** | Ember, a small relational engine with SQL and transactions, in process |
| **Graphics** | a canvas, shapes, text and a real compressing PNG writer |
| **Interfaces** | declarative `app` blocks that run in a window, in a terminal, or as JSON |
| **Web** | an HTTP client and a working server you hand a function to |
| **AI** | tensors, dense layers, a network, a trainer and a tokeniser |
| **Forge** | package manager: local and git packages, lockfile, checksums, `.forge` archives, no registry |
| **Debugger** | breakpoints with conditions, step in/over/out, call stack, variables, watches, memory |
| **Studio** | native AppKit editor: explorer, problems, outline, git, debugger, terminal, playground, command palette, minimap, completion, hover, go to definition, rename |
| **Guidebook** | thirty chapters, every example runnable, readable in the terminal or inside Studio |
| **Browser** | a web browser whose engine — addresses, HTML, CSS, layout, blocking, caching, reading — is 3,000 lines of SPRFST in [`browser/`](browser/) |
| **Examples** | twenty one complete programs in [`examples/`](examples/) |

## Where things live

```
compiler/include/sprfst/   headers: the shape of everything
compiler/src/              the compiler, the runtime and the tools
std/                       the part of the library written in SPRFST
examples/                  21 complete programs
guidebook/                 30 chapters
docs/                      generated by `sprfst docs`
ide/macos/Sources/         SPRFST Studio, in Swift and AppKit
browser/engine/               the browser engine, in SPRFST
browser/mac-app/Sources/     the browser window, in Swift and AppKit
assets/logo/               the mark, drawn by a SPRFST program
tools/                     macOS bundle, disk image, guidebook checker
tests/run_tests.sh         the whole suite
```

## Status, honestly

This is version 0.1.0-beta. It runs, and the parts below are the ones
that are not finished. They are listed here rather than hidden.

- **`sprfst build` does not produce a standalone binary.** It writes
  `build/program.spir`, the optimised instruction listing, and programs
  are executed by the runtime. A native AArch64 / Mach-O backend is the
  next major piece of work; `-O3` is reserved for it.
- **Concurrency is cooperative, not parallel.** Threads are real
  operating system threads, but the interpreter holds one lock and
  hands it over at safe points and whenever a task blocks on input,
  output or the network. Input and output overlap properly; two pieces
  of SPRFST code never run at the same instant.
- **No TLS.** `http.get` and `http.post` speak plain HTTP, so an
  `https://` address gives back `nil`.
- **`drop` methods are not called.** `defer` is the cleanup mechanism
  that works today, and the guidebook uses it.
- **The move checker is simple.** A name is treated as moved from the
  line the move appears on, so moving inside one branch of an `if`
  counts for everything after it.
- **The test suite needs no GNU tools and no text locale.** It used
  `timeout`, which macOS does not have, and `grep` on binary data,
  which BSD grep refuses to match in a UTF-8 locale — so on a Mac the
  examples, the guidebook and the PNG check all reported failure and
  `build_macos_app.sh` refused to package. The scripts now carry their
  own time limit, read signatures with `od`, and run under `LC_ALL=C`.
- **Studio's first compile found one error, and its first launch found
  a broken layout.** The error was `NSRulerView`, which redeclares
  `initWithCoder:` as non-failable. The layout was nested
  `NSSplitView`s choosing divider positions before the window had a
  size, which left the editor 140 points wide; the window is now laid
  out with constraints and its own draggable dividers, and the chrome
  is set in a handwriting face throughout.
- **Then the editor appeared empty, and that was one line.** The line
  number ruler filled the rectangle AppKit handed it instead of its
  own bounds. Since macOS 14 that rectangle can be much larger than
  the ruler, and a view's drawing is no longer clipped to it, so the
  ruler painted the editor background over the code, over the file
  tabs, over the explorer and over the top bar — everything drawn
  before it. The line numbers themselves survived because the ruler
  drew them afterwards, which is exactly what the screenshot showed.
  Every view that draws itself now fills its bounds and clips to
  them. In the same pass the editor's text view was built on TextKit 1
  explicitly: a text view made the plain way has been a TextKit 2 view
  since Ventura, and it rebuilds its whole text system the first time
  anything reads its `layoutManager` — which a line number ruler does
  on every draw, losing the keyboard focus with it.
- **Studio had never been compiled until now.** The whole editor is
  written — 3,300 lines of Swift and AppKit in `ide/macos/Sources/` —
  and so are the bundle and disk image scripts, but this repository was
  developed on Linux, where `swiftc`, AppKit, `codesign` and `hdiutil`
  do not exist. `make stage` lays out the bundle and the contents of
  the disk image anywhere so the layout, the `Info.plist` and the icon
  can be checked, and it says plainly that the staged bundle has no
  executable in it. `tools/check_swift.sh` goes as far as a machine
  with no Swift can: brackets, every `#selector` target, the AppKit
  initialisers and the single entry point. The first `make dmg` on a
  Mac is still the first time that code will be compiled.

- **The PDFs use the base fonts, not an embedded one.** Helvetica and
  Courier are what every reader already has, so the files stay small
  and need no licence. Characters outside those fonts — box drawing,
  the Mac modifier keys — are spelled out instead.
- **The disk image is ISO 9660, not HFS+.** `hdiutil` only exists on a
  Mac, so away from one the image is written by `tools/make_iso.spf`.
  macOS mounts ISO 9660 by double click, and files on such a volume are
  mode 555, so the installer inside it is runnable. On a Mac `make dmg`
  still uses `hdiutil` and HFS+, which is the better image.

- **The browser has no JavaScript engine and no layout beyond lines and
  blocks.** It is written up properly in [`browser/README.md`](browser/README.md):
  what it does that nothing else does, and the eight things it cannot
  do. Pages that are HTML arrive whole and quickly; pages that build
  themselves in the browser arrive empty, and it says so rather than
  spinning.

Everything else in this README was run on the machine that wrote it.
`make test` is the proof: 61 checks covering the language suite, all
twenty one examples, every command line verb, Forge digests, the Studio
service, the debugger, the disk image and the PDFs written and read back, the
formatter round tripped over every file, all 100 guidebook code blocks,
the browser engine's own thirty tests, and nineteen more that start a
server full of adverts and check what the browser made of it.

The collector is checked as well as the compiler: `SPRFST_GC_STRESS=1`
makes the runtime collect garbage on every single allocation, and every
example and tool is run that way under AddressSanitizer. That is how the
one real bug of this round was found — a native that allocated a list,
then allocated its contents, could have the half built list collected
underneath it. Natives now hold a scope of temporaries that lasts until
they return.

## Licence

Written to be read. Take it apart.
