# SPRFST — basics to pro

A shooting script for one video, about fifty minutes. Every command in
it has been run; every output shown is what the tool really prints. If
something in the repository changes and a line here stops being true,
the line is wrong, not the viewer.

**Setup before you record**

| | |
|---|---|
| Terminal | 110 × 32, deep black `#0B0B0D`, text `#E8E8E6`, accent `#FFA136` |
| Font | any mono at 16pt or larger — small type is the commonest fault in a coding video |
| Editor on screen | SPRFST Studio, or any editor with the same dark palette |
| Repository | a clean checkout at `~/SPRFST-Beta`, **not** built yet, so scene 1 is real |
| Second terminal | already in `~/SPRFST-Beta`, for the moments when you need two |
| Recording | 1440p, cursor highlighting on, keystroke overlay off except where the script says otherwise |

**The one rule:** type everything. No cuts to a finished file. The
language is small enough that typing it is the demonstration.

---

## 0:00 — Cold open

**ON SCREEN** Black. The mark fades in, then one line of terminal:

```
$ sprfst run hello.spf
hello
```

**SAY**

> This is a programming language called SPRFST. It is not a layer over
> Python, or JavaScript, or C. There is a lexer, a parser, a type
> checker, an optimiser and a register machine, all written from
> nothing, and in the next fifty minutes you are going to learn the
> whole of it — from printing a line to writing a web browser in it.
> Everything I type, you can type. Nothing is prepared off screen.

---

## 0:40 — Scene 1. Getting it

**ON SCREEN**

```
$ cd ~/SPRFST-Beta
$ make
```

Let the build run in full. It takes about ten seconds. Point at the
last line:

```
  ✓ built build/bin/sprfst  (Linux/x86_64)
```

**SAY**

> A C compiler and make. That is the whole list. No package manager to
> install first, no network, no toolchain the size of an operating
> system. Ten seconds and you have the compiler, the runtime, the
> formatter, the linter, the test runner, the debugger, the package
> manager and the documentation generator — one binary, about four
> hundred kilobytes.

**ON SCREEN**

```
$ ./build/bin/sprfst help
```

**SAY**

> Thirteen verbs. That is deliberate. You should be able to hold the
> whole command line in your head.

**ON SCREEN**

```
$ sudo make install
$ sprfst --version
```

**SAY**

> From here on I will type `sprfst` rather than the path.

---

## 3:00 — Scene 2. The shape of a program

**ON SCREEN** New file `hello.spf`, typed live:

```sprfst
use std.io

fn main() {
    io.say("hello")
    io.say(2 + 2)        ~~ not only text
}
```

```
$ sprfst run hello.spf
hello
4
```

**SAY**

> Three things to notice. `use std.io` brings in the input and output
> part of the library — nothing is global by accident. `fn main` is
> where a program begins. And a comment is two tildes, not two slashes,
> because this language is not pretending to be C.
>
> `io.say` takes any value, not only text. It printed the number
> without being asked to convert it.

**ON SCREEN** Break it on purpose — change `io.say` to `io.sayy`:

```
$ sprfst run hello.spf
error[E0220]  `io` has no function called `sayy`
  ┌─ hello.spf:4:8
  │
4 │     io.sayy(2)
  │        ━━━━ not found in this module
  │
  ├ note  available: say, print, warn, ask, read_line, flush
```

**SAY**

> Look at the error. The code, the file, the line, the column, the
> underline — and then the part that matters: the six functions that
> module does have. Error messages are not an afterthought here. Each
> one is written to be read by somebody who is stuck.

---

## 5:30 — Scene 3. How to follow along

**ON SCREEN**

```
$ sprfst run learn/tour.spf
```

Show the welcome, then lesson one, then type `answer`, paste it, type
`check`, and show the green **that is it**.

**SAY**

> Before we go further: there is an interactive tour in the repository,
> and it is the same twenty six steps as this video, in the same order.
> It writes you a file, you finish it, you type check, and your file is
> handed to the real interpreter — it compares real output, not a
> stored answer. If you want to pause the video at any point and do the
> matching lesson, the numbers line up.
>
> `run` runs your file, `hint` nudges, `answer` shows one way, `list`
> shows where you are. Your work lives in a folder in your home
> directory, so nothing you write ends up in the repository.

---

## 7:00 — Scene 4. Values and names — *tour 2 and 3*

**ON SCREEN**

```sprfst
use std.io

fn main() {
    let name = "ada"
    var count = 0
    count = count + 1
    io.say("{name} has {count}")
}
```

**SAY**

> `let` is a name that will never change. `var` is one that will. The
> default is the one that cannot surprise you later.
>
> I did not write a type anywhere, but both of those have one, and the
> compiler knows it. Watch.

**ON SCREEN** Add `count = "many"` and run it.

```
error[E0201]  Type mismatch
  ├ you gave      Text
  ├ required      Int
```

**SAY**

> Inference, not absence. Now the braces in that text: anything inside
> them is filled in. If you ever need a real brace in a string, double
> it.

**ON SCREEN**

```sprfst
io.say("{7 / 2}")
io.say("{to_int(7 / 2)}")
io.say("{17 % 5}")
```

```
3.5
3
2
```

**SAY**

> Here is the first thing that catches people. `Int` divided by `Int`
> gives you a `Num`, a fractional number — seven over two is three
> point five, not three. Most languages quietly throw the half away.
> This one does not, and if you want the whole part you say so.

---

## 10:00 — Scene 5. Decisions and loops — *tour 4 and 5*

**ON SCREEN**

```sprfst
let hour = 20
let greeting = if hour < 12 { "morning" } else { "evening" }
io.say(greeting)

if hour > 18 and not (hour > 22) { io.say("supper") }
```

**SAY**

> `if` is an expression. It has a value, so you can give it straight to
> a name. That is why there is no question-mark-colon operator — it
> would only be a second way of writing this.
>
> And the operators are words. `and`, `or`, `not`. You read them.

**ON SCREEN**

```sprfst
for n in 1...3 { io.say("{n}") }

var printed = 0
for n in 1...20 {
    if n % 3 != 0 { skip }
    io.say("{n}")
    printed = printed + 1
    if printed == 4 { break }
}
```

**SAY**

> Two dots is up to; three dots includes the end. `skip` goes to the
> next turn, `break` leaves the loop. There is also a bare `loop` when
> you want to decide the ending yourself.

---

## 13:00 — Scene 6. Functions — *tour 6*

**ON SCREEN**

```sprfst
use std.io

fn double(n: Int) -> Int => n * 2

fn apply_twice(value: Int, change: fn(Int) -> Int) -> Int {
    give change(change(value))
}

fn main() {
    io.say("{apply_twice(10, double)}")
    io.say("{5 |> double}")
}
```

```
40
10
```

**SAY**

> `give` hands the answer back. A function that is one expression can
> drop the braces and use a fat arrow.
>
> Parameters have types and so does the answer. That is not ceremony —
> it is what lets the compiler tell you precisely where you went wrong,
> three files away.
>
> Functions are values. `apply_twice` takes one. And the pipe operator
> sends a value through a function left to right, which is how you read
> a chain of them without turning it inside out.

---

## 16:00 — Scene 7. Text, lists, maps — *tour 7, 8 and 9*

**ON SCREEN**

```sprfst
let line = "  SPRFST, a language  "
let clean = line.trim()
io.say(clean.lower())
io.say("{clean.split(", ")}")
io.say(clean.replace("language", "tool"))
```

**SAY**

> Text is a value. Every one of these gives you a new piece of text and
> leaves the old one alone.

**ON SCREEN**

```sprfst
let numbers = [5, 3, 9, 1]
io.say("{numbers.map(fn(n) => n * n)}")
io.say("{numbers.filter(fn(n) => n > 3)}")
io.say("{numbers.reduce(0, fn(total, n) => total + n)}")
io.say("{numbers.sort_by(fn(a, b) => a > b)}")
```

**SAY**

> Map, filter, reduce, sort. `sort_by` takes a test that answers one
> question: does `a` come first? And it gives you a sorted copy — your
> list is still your list.

**ON SCREEN**

```sprfst
var ages = ["ada": 36, "alan": 41]
ages.set("grace", 45)
io.say("{ages.get("ada") ?? 0}")
io.say("{ages.has("nobody")}")
```

**SAY**

> A map is written with colons. And notice `get` — it did not give me
> back a number. It gave me back a number *or nothing*, and I had to
> say what to do about the nothing. Which is the next scene.

---

## 20:00 — Scene 8. Nothing, and failure — *tour 10 and 11*

**ON SCREEN**

```sprfst
use std.io

fn first_word(line: Text?) -> Text {
    give line?.split(" ")?.first() ?? "nothing"
}

fn main() {
    io.say(first_word("hello there"))
    io.say(first_word(nil))
}
```

```
hello
nothing
```

**SAY**

> A question mark on a type means *or nothing*. `Text?` is text, or
> nothing at all. The compiler will not let you use one where plain
> text is wanted, so a missing value cannot slip past you and turn up
> as a crash an hour later.
>
> Question-mark-dot calls the method only when there is something
> there. Two question marks supply the value for the nothing case. You
> can chain the first and finish with the second, which is this line.

**ON SCREEN**

```sprfst
fn parse_age(text: Text) -> Result<Int> {
    let n = text.to_int()
    if n == nil { give Err("'{text}' is not a number") }
    give Ok(n ?? 0)
}

fn main() {
    for input in ["36", "ada"] {
        match parse_age(input) {
            when Ok(age) -> io.say("age {age}")
            when Err(why) -> io.say("no: {why}")
        }
    }
}
```

**SAY**

> Missing and failed are different ideas, and they get different tools.
> A thing that can fail hands back a `Result`: either `Ok` with the
> value or `Err` with the reason. `match` pulls it apart and makes you
> deal with both sides.
>
> There are no exceptions appearing from nowhere. If a function can
> fail, it says so in its type, and you can see it at the call.

---

## 24:00 — Scene 9. Objects, data, traits — *tour 13, 14 and 15*

**ON SCREEN**

```sprfst
object Counter {
    name: Text = "counter"
    value: Int = 0

    fn bump(self) { self.value = self.value + 1 }
    fn report(self) -> Text => "{self.name} is at {self.value}"
}
```

**SAY**

> Fields carry their defaults with them, so building one means naming
> only what is different. Methods take `self` first.

**ON SCREEN**

```sprfst
data Point {
    x: Num
    y: Num
}

let a = Point { x: 1.0, y: 2.0 }
let b = Point { x: 1.0, y: 2.0 }
io.say("same: {a == b}")      ~~ true
```

**SAY**

> `data` is the other kind: a thing with no identity of its own. Two
> points with the same numbers *are* the same point. Two counters with
> the same count are still two counters. Measurement versus thing — and
> the language gives you a different word for each.

**ON SCREEN**

```sprfst
trait Greeter {
    fn name(self) -> Text
    fn greet(self) -> Text => "hello, {self.name()}"
}

object Person {
    given: Text = "friend"
    fn name(self) -> Text => self.given
}

object Robot {
    serial: Int = 1
    fn name(self) -> Text => "unit {self.serial}"
}

impl Greeter for Person {}
impl Greeter for Robot {}

fn main() {
    let crowd = [Person { given: "Ada" }, Robot { serial: 7 }]
    for one in crowd { io.say(one.greet()) }
}
```

**SAY**

> A trait is a promise: these functions exist. It can also carry a
> finished method written in terms of the ones it demands — `greet` is
> written once and both of these get it.
>
> There is no inheritance here. No base class, no super, no diamond. A
> small trait, kept, is worth more than a family tree, and when you
> want behaviour from two places you keep two promises.

---

## 29:00 — Scene 10. Generics and modules — *tour 16 and 17*

**ON SCREEN**

```sprfst
fn first_of<T>(items: [T]) -> T? {
    if items.is_empty() { give nil }
    give items[0]
}

fn larger<T: Ord>(a: T, b: T) -> T {
    if a > b { give a }
    give b
}
```

**SAY**

> One function, every type, still fully checked. The bound after the
> colon says what you are allowed to assume — here, that the thing can
> be compared.

**ON SCREEN** Two files side by side.

```sprfst
~~ money.spf
module money

pub fn vat(amount: Num) -> Num => amount * 0.2
fn secret() -> Text => "not visible outside"
```

```sprfst
~~ main.spf
use std.io
use money

fn main() { io.say("{money.vat(100.0)}") }
```

**SAY**

> A file that names itself a module can be used by its neighbours.
> `pub` is what gets out; everything else belongs to the file. No
> header, no export list at the bottom, no build file to register it
> in.

**ON SCREEN**

```
$ sprfst new orchard
  created orchard

     cd orchard
     sprfst run .

$ cd orchard && sprfst run .
hello from orchard
the numbers add up to 31
```

**SAY**

> And that is a project: `src`, `tests`, `assets`, `packages`, and a
> `project.sprfst` describing it. `sprfst run .` runs the whole thing
> rather than one file.

---

## 32:00 — Scene 11. Memory — *tour 21*

**ON SCREEN**

```sprfst
use std.io

fn add_one(items: [Int]) { items.push(1) }

fn main() {
    var numbers = [0]
    add_one(numbers)
    io.say("{numbers}")            ~~ [0, 1]

    let copy = clone(numbers)
    numbers.push(99)
    io.say("copy is still {copy}") ~~ [0, 1]
}
```

**SAY**

> Lists, maps and objects are references. Hand one to a function and
> the function has the same one you do — no copy was made, and the
> change you can see is the point. When you want your own, `clone` says
> so out loud, in the code, where a reader can see the cost.

**ON SCREEN**

```sprfst
fn peek(items: ref [Int]) -> Int => items.len()
fn consume(items: own [Int]) -> Int => items.len()
```

**SAY**

> And when ownership matters you can write it down. `ref` says I am
> only borrowing this. `own` says I am taking it, and the compiler will
> stop the caller using it afterwards.
>
> There is no collector pause you can feel and no `free` to forget.

**ON SCREEN**

```sprfst
fn main() {
    defer io.say("finished")
    io.say("working")
}
```

**SAY**

> `defer` runs when the function leaves, however it leaves. Close the
> file next to where you opened it, and stop thinking about it.

---

## 35:00 — Scene 12. Doing several things — *tour 20*

**ON SCREEN**

```sprfst
use std.io

task work(id: Int) -> Int {
    give id * 100
}

fn main() {
    let a = spawn work(1)
    let b = spawn work(2)
    io.say("{await a} {await b}")
}
```

**SAY**

> `task` is a function that can run alongside others. `spawn` starts
> one and hands you back a future; `await` waits for the answer.
>
> There are also real threads, channels, locks and atomics in
> `std.thread`. Be honest about this one: tasks run on real threads,
> but the interpreter holds a lock, so this is concurrency for
> overlapping waiting, not for using eight cores at once. That is in
> the README under Status, and it is the next big piece of work.

---

## 38:00 — Scene 13. Tests, and the tools — *tour 19*

**ON SCREEN**

```sprfst
use std.testing

fn add(a: Int, b: Int) -> Int => a + b

test "adding" {
    testing.same(add(2, 2), 4, "two and two")
    testing.yes(add(2, 2) > 3, "bigger than three")
}

bench "a thousand pushes" {
    var xs: [Int] = []
    var i = 0
    while i < 1000 { xs.push(i); i = i + 1 }
}
```

```
$ sprfst test
  pass  adding  0.01ms
  bench a thousand pushes  13493 ops/s  0.074ms each

  1 passed, 0 failed
```

**SAY**

> A test is a block with a name. A bench is a block that gets timed and
> reported in operations per second. No framework to install, no
> annotations, no runner to configure.

**ON SCREEN** Each in turn:

```
$ sprfst fmt src/main.spf
  unchanged  src/main.spf

$ sprfst lint src/main.spf
  clean  1 file linted

$ sprfst docs
  docs  3 pages  ->  docs/

$ sprfst debug src/main.spf
```

In the debugger: `b 5`, `r`, `v`, `n`, `k`, `q`.

**SAY**

> Formatter, linter, documentation generator, debugger. In the box, one
> word each.
>
> The debugger is a real one: breakpoints, conditional breakpoints,
> step in, step over, step out, the call stack, the variables in scope,
> watches, and the memory the runtime is holding. It is the same binary
> — nothing to attach.

---

## 42:00 — Scene 14. Packages — *tour 25*

**ON SCREEN**

```
$ sprfst add ../some-library
$ cat project.sprfst
$ cat sprfst.lock
$ sprfst install
```

**SAY**

> The package manager is called Forge. A package is a folder or a git
> URL — there is no central registry, which means there is nothing to
> go down, nothing to be bought, and nobody to take your name.
>
> Everything in the lockfile carries a SHA-256 of its contents, so the
> code you install is the code you reviewed. That is the same
> `hash.sha256` you can call yourself in three lines.

---

## 44:00 — Scene 15. What it is for

**ON SCREEN**

```
$ make studio
```

Studio opens. Show the editor, the explorer, the problems list as you
type a mistake, the outline, the command palette, the guidebook panel.

**SAY**

> This is SPRFST Studio. It is a Mac application — AppKit, not a web
> page in a window — and it is written to the same taste as the
> language: deep black, one warm accent, nothing on screen that is not
> doing something.

**ON SCREEN**

```
$ make browser
```

The browser opens. Load a news site. Point at the bottom right:
`6 ms · 4 kB · 5 blocked · 4 hidden`. Press ⌘K for the Lens, ⌘U for
Ember.

**SAY**

> And this is a web browser whose engine is written in SPRFST. Three
> thousand lines: the address parser, the HTML parser, the style
> engine, the layout engine, the ad blocker, the cache and the reader.
> The window is AppKit and paints what the engine hands it — it parses
> nothing.
>
> Four hundred and thirteen blocking rules, checked before a request is
> made, so a blocked advert is never fetched, never parsed and never
> laid out. The number in the corner is what the page cost you, and it
> is always there.
>
> I show you this not because you need a browser, but because it is the
> answer to the only question that matters about a new language: can
> you actually build something with it.

---

## 47:00 — Scene 16. The honest part

**ON SCREEN** The Status section of the README, scrolling slowly.

**SAY**

> Before you go, the things it does not do, because a language that
> only tells you the good parts is selling you something.
>
> `sprfst build` does not yet produce a standalone binary — it writes
> optimised instructions and the runtime executes them. A native ARM
> backend is the next major piece of work.
>
> There is no TLS in the runtime, so HTTPS shells out to curl.
> Concurrency is threads under one lock. The browser has no JavaScript
> engine, and its layout is lines and blocks, not grid and flexbox.
>
> All of that is written down in the README, in the browser's README,
> and in the guidebook, in the same words I just used. You will find
> out eventually; you may as well find out from me.

**ON SCREEN** Final card: the mark, then

```
sprfst run learn/tour.spf
```

**SAY**

> Twenty six lessons, the same order as this video. Start it, and in an
> afternoon you will have written every one of them yourself.

---

## Appendix — what to cut for a short version

A fifteen minute cut that still teaches something: scenes 1, 2, 4, 6,
8, 9 and 15. Keep the error message in scene 2 and the `Result` in
scene 8 — those two are why somebody would choose this over what they
already use.

## Appendix — the lessons and the scenes

| scene | tour lessons |
|---|---|
| 4 | 2, 3 |
| 5 | 4, 5 |
| 6 | 6 |
| 7 | 7, 8, 9 |
| 8 | 10, 11, 12 |
| 9 | 13, 14, 15 |
| 10 | 16, 17 |
| 11 | 21 |
| 12 | 20 |
| 13 | 19, 24 |
| 14 | 25 |
| 15 | 22, 23, 26 |
