# Running SPRFST from a terminal

You downloaded the project. Here is every command, in order, with what
each one prints. Nothing here needs the disk image.

Written for macOS. It works the same on Linux; where the two differ, it
says so.

---

## 1. Get the tools

SPRFST is built with a C compiler and `make`, both of which come with
Apple's command line tools. If you have never installed them:

```
xcode-select --install
```

Check you have them:

```
cc --version
make --version
```

If `cc` answers, you are ready. (On Linux: `sudo apt install build-essential`.)

---

## 2. Open the project in a terminal

If you downloaded a zip, unzip it and go in:

```
cd ~/Downloads
unzip SPRFST-Beta.zip
cd SPRFST-Beta
```

Or clone it:

```
git clone https://github.com/FellowPythonCoder/SPRFST-Beta.git
cd SPRFST-Beta
```

You should see this:

```
ls
```

```
Makefile   README.md  assets  compiler  docs  examples
guidebook  ide        std     tests     tools   project.sprfst
```

---

## 3. Build the compiler

```
make
```

About ten seconds. The last line is:

```
  ✓ built build/bin/sprfst  (Darwin/arm64)
```

That one file, `build/bin/sprfst`, is the whole toolchain: compiler,
runtime, debugger, formatter, test runner, package manager and the
service SPRFST Studio talks to.

---

## 4. Run your first program

```
./build/bin/sprfst run examples/01-hello.spf
```

```
hello, world
```

The compiler finds its standard library by looking next to itself, so
this works from any folder, with no environment variables to set.

Try a few more:

```
./build/bin/sprfst run examples/06-collections.spf
./build/bin/sprfst run examples/11-errors.spf
./build/bin/sprfst run examples/21-neural-network.spf
```

All twenty one are in `examples/`:

```
ls examples
```

---

## 5. Put `sprfst` on your PATH (optional, recommended)

So you can type `sprfst` anywhere instead of `./build/bin/sprfst`:

```
sudo make install
```

That copies two things:

```
/usr/local/bin/sprfst
/usr/local/lib/sprfst/std
```

Check it:

```
cd ~
sprfst --version
```

```
sprfst 0.1.0-beta (Ember)
```

To remove it again:

```
sudo rm -rf /usr/local/bin/sprfst /usr/local/lib/sprfst
```

The rest of this guide writes `sprfst`. If you skipped this step, write
`./build/bin/sprfst` instead, from inside the project folder.

---

## 6. Start your own project

```
cd ~
sprfst new hello
cd hello
sprfst run .
```

```
hello from hello
the numbers add up to 31
```

`sprfst new` writes three files:

```
hello/project.sprfst     name, version, entry point
hello/src/main.spf       your program
hello/.gitignore
```

Open `src/main.spf` in any editor, change it, and `sprfst run .` again.

---

## 7. The commands

```
sprfst help
```

| command | what it does |
|---|---|
| `sprfst run <file>` | compile and run a file |
| `sprfst run .` | compile and run the project in this folder |
| `sprfst check .` | type check, print nothing if it is fine |
| `sprfst test` | run every `tests/*.spf` in the project |
| `sprfst fmt .` | format the source in place |
| `sprfst fmt --check .` | fail instead of rewriting; for a pre-commit hook |
| `sprfst lint .` | style and clarity warnings |
| `sprfst build .` | write `build/program.spir` |
| `sprfst docs .` | write Markdown documentation to `docs/` |
| `sprfst debug <file>` | run under the debugger |
| `sprfst new <name>` | start a project |
| `sprfst add --path=../lib` | add a package with Forge |
| `sprfst install` | fetch everything `project.sprfst` lists |
| `sprfst clean` | delete `build/` |

Options that work with all of them:

```
-O0 -O1 -O2 -O3      how hard to optimise (run defaults to -O1, build to -O2)
--time               print parse, check, lower and run timings
--ir                 print the instruction listing
--json               machine readable diagnostics, for editors
--quiet  --no-color  --version
--                   everything after this goes to the program, as sys.args()
```

For example:

```
sprfst run --time examples/01-hello.spf
```

```
  1 file   parse 0.0ms  check 0.0ms  lower 0.0ms  run 0.0ms  5 instr  0 KB peak  0 gc
hello, world
```

---

## 8. The interesting examples

**A window, in the terminal.** The GUI framework draws to a real window
on a Mac and to the terminal everywhere else. Force the terminal
version with `SPRFST_UI=term`:

```
SPRFST_UI=term sprfst run examples/18-gui-counter.spf
```

```
  SPRFST Counter
  ------------------------------------------
  Count is 0
  ----------------------------
  [1] Add 1
  [2] Take 1
  ...
  press a number to act, q to quit
  >
```

Press `1`, then `q` to leave.

**A web server.**

```
sprfst run examples/19-web-server.spf
```

```
serving http://localhost:8080  (ctrl-c to stop)
```

Open <http://localhost:8080> in a browser, or in another terminal:

```
curl http://localhost:8080/health
```

Stop it with `ctrl-c`.

**A database.**

```
sprfst run examples/14-database.spf
```

**A neural network, trained from scratch.**

```
sprfst run examples/21-neural-network.spf
```

---

## 9. The debugger

```
sprfst debug examples/05-functions.spf
```

At the `(debug)` prompt:

```
b 15            break at line 15
b 15 if n > 3   break only when the condition holds
r               run
n               next line, over calls
s               step into a call
o               step out
c               continue
v               variables here
k               call stack
p name          print one value
w expr          watch an expression
m               memory
l               list breakpoints
d 0             delete breakpoint 0
?               help
q               quit
```

A whole session, start to finish:

```
sprfst debug examples/05-functions.spf
(debug) b 15
  break 0 at line 15
(debug) r
  breakpoint  05-functions.spf:15  in main
    14  fn main() {
    15 >     io.say("2 + 3 = {add(2, 3)}")
(debug) v
  double           nil
  total            nil
(debug) k
  ▸ 1  main  05-functions.spf:15
    0  <start>  05-functions.spf:28
(debug) c
2 + 3 = 5
(debug) q
```

Quitting with `q` exits with status 1 and says `stopped by the
debugger`. That is normal — it means the program did not run to the end.

---

## 10. Build SPRFST Studio, the editor (macOS only)

Studio is a native AppKit application. Building it needs Swift, which
comes with Xcode or the command line tools:

```
swiftc --version
```

If that answers, build everything:

```
./tools/build_macos_app.sh
```

It builds the compiler, runs the test suite, checks the Swift sources,
draws the icons, writes `Info.plist`, compiles the editor for
`arm64-apple-macos12.0`, and signs it. The result:

```
dist/SPRFST Studio.app
```

Run it from the terminal:

```
open "dist/SPRFST Studio.app"
```

Install it properly:

```
cp -R "dist/SPRFST Studio.app" /Applications/
open "/Applications/SPRFST Studio.app"
```

After that, `.spf` files show the SPRFST icon and open in Studio when
double clicked.

Inside Studio: `⌘P` command palette, `⌘R` run, `⌘B` build, `⌘U` test,
`⌘D` debug, `⌘\` toggle breakpoint, `⌃\`` terminal, `⌘0` guidebook.

**Be honest with yourself about this step.** Studio's 3,300 lines of
Swift have never been through a compiler — this project was developed on
Linux, where `swiftc` does not exist. `tools/check_swift.sh` checks
brackets, selectors, AppKit initialisers and the entry point, and it
passes, but the first `swiftc` run will be the first real compile and
may well find mistakes. The language, the compiler and everything in
sections 1 to 9 are not affected by this: they are tested on every
change.

If you only want to see the bundle layout without a Mac:

```
./tools/build_macos_app.sh --stage
```

---

## 11. The `make` targets

```
make              build the compiler
make test         the whole test suite, 54 checks
make docs         regenerate docs/
make guidebook    compile every code block in the guidebook
make pdf          typeset guidebook/pdf — 30 chapters and the book
make app          dist/SPRFST Studio.app        (needs a Mac)
make dmg          dist/SPRFST-0.1.0-beta.dmg
make stage        lay out the app and image contents without building them
make install      /usr/local/bin + /usr/local/lib   (needs sudo)
make clean        delete build/
```

Run the tests on your own copy — it is the fastest way to know the
download is sound:

```
make test
```

```
  54 passed, 0 failed  3s
```

---

## 12. Learning the language

Thirty chapters, every example runnable:

```
open guidebook/pdf/SPRFST-Guidebook.pdf      the whole book
ls guidebook/pdf                             one PDF per chapter
ls guidebook                                 the same thing in Markdown
```

Every code block in those chapters is compiled by the test suite, so
nothing in them is out of date.

---

## 13. When something goes wrong

**`sprfst: command not found`** — you have not run `sudo make install`,
or `/usr/local/bin` is not on your PATH. Use `./build/bin/sprfst` from
the project folder, or add this to `~/.zshrc`:

```
export PATH="/usr/local/bin:$PATH"
```

**`Cannot read <file>`** — the path is wrong. `ls examples` and copy a
name exactly; they are numbered `01-` to `21-`.

**`cannot find module std.io`** — the compiler cannot see its standard
library. It looks next to its own binary, then in
`/usr/local/lib/sprfst`. Point it somewhere explicitly if you have
moved things:

```
SPRFST_HOME=/path/to/SPRFST-Beta sprfst run myfile.spf
```

**A build that fails after you edited the C sources** — object files can
go stale:

```
make clean && make
```

**macOS refuses to open something you downloaded** — right click it and
choose Open, instead of double clicking it.

**`sprfst debug` exits with 1** — that is what quitting the debugger
does. Nothing is wrong.

---

## The two minute version

```
cd SPRFST-Beta
make
./build/bin/sprfst run examples/01-hello.spf
sudo make install
sprfst new myapp && cd myapp && sprfst run .
```
