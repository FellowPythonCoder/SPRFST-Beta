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

```
make                       # builds build/bin/sprfst
make test                  # 48 checks: language, examples, CLI, guidebook
./build/bin/sprfst run examples/01-hello.spf
```

To use it from anywhere:

```
sudo make install          # /usr/local/bin/sprfst + /usr/local/lib/sprfst/std
```

On a Mac with the Xcode command line tools, this also builds the editor:

```
make app                   # dist/SPRFST Studio.app
make dmg                   # dist/SPRFST-Studio.dmg, mountable and verified
make stage                 # lay both out without a Mac, to check them
```

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
- **SPRFST Studio has never been compiled.** The whole editor is
  written — 3,300 lines of Swift and AppKit in `ide/macos/Sources/` —
  and so are the bundle and disk image scripts, but this repository was
  developed on Linux, where `swiftc`, AppKit, `codesign` and `hdiutil`
  do not exist. `make stage` lays out the bundle and the contents of
  the disk image anywhere so the layout, the `Info.plist` and the icon
  can be checked, and it says plainly that the staged bundle has no
  executable in it. The first `make dmg` on a Mac is the first time
  that code will be compiled.

Everything else in this README was run on the machine that wrote it.
`make test` is the proof: 48 checks covering the language suite, all
twenty one examples, every command line verb, Forge digests, the Studio
service, the debugger, and all 98 guidebook code blocks.

## Licence

Written to be read. Take it apart.
