# SPRFST in ten lessons — shooting script

For a video of **this page**: `new/index.html`, ten lessons, about
twenty eight minutes. Every command and every output below was run
before it was written down. If the repository changes and a line here
stops being true, the line is wrong.

**Before you record**

| | |
|---|---|
| Two windows | the page on the left (full height), a terminal on the right — or alt-tab between them |
| Browser | hide bookmarks and extensions; the page is black, let it be the whole frame |
| Terminal | 100 × 28, black `#0B0B0D`, 16pt or larger |
| Runner | `sprfst run new/serve.spf` started **on camera** in scene 1 — the green dot turning on is the proof |
| Zoom | at least 140% in the browser; code that cannot be read teaches nothing |
| Recording | 1440p, 30fps is plenty, cursor highlight on |

**The rule:** press Run on camera, every time. The whole claim of this
page is that the output is real, and the viewer only believes it if
they watch it arrive.

---

## 0:00 — Cold open  *(40s)*

**ON SCREEN** Black. The bolt mark. Then the page, scrolling slowly
from lesson 1 to lesson 10 and back, no narration for three seconds.

**SAY**

> This is a language called SPRFST. Not a layer over Python or C —
> a lexer, a parser, a type checker, an optimiser and a register
> machine, written from nothing. In the next half hour you are going to
> learn all of it. Not the highlights. All of it: there is a table at
> the end of this page listing every part of the language, and by the
> time we get there you will have used every row.

---

## 0:40 — Scene 1. Getting the runner on  *(2m)*

**ON SCREEN** The terminal.

```
$ cd ~/SPRFST-Beta
$ make
  ✓ built build/bin/sprfst  (Darwin/arm64)
$ sprfst run new/serve.spf

  SPRFST — the tour, in a browser

  open        http://localhost:7070
  runner      /Users/you/SPRFST-Beta/build/bin/sprfst
```

Switch to the browser, open `http://localhost:7070`. Point at the grey
dot in the sidebar, reload, and show it turn **green**:
*runner on — your code really compiles*.

**SAY**

> A C compiler and make. Ten seconds. That one binary is the compiler,
> the runtime, the formatter, the linter, the test runner, the
> debugger, the package manager and the documentation generator.
>
> This page is served by a program written in SPRFST — about a hundred
> and sixty lines in `new/serve.spf`. When I press Run, the code goes to
> that program, which writes it to a file and hands it to the real
> compiler. There is no interpreter hiding in the browser and there are
> no stored answers. That green dot means what it says.

**ON SCREEN** Scroll to lesson 1's diagram. Trace it with the cursor:
source → lexer → parser → types → instructions → output.

**SAY**

> That is the whole journey of your file. And notice where the dashed
> line goes back: if the type checker is unhappy, nothing runs, and you
> get told the line, the column and a way out.

---

## 2:40 — Scene 2. The smallest whole program  *(2m)*

**ON SCREEN** Lesson 1's editor. Press **Run**. The output panel label
changes from *recorded output* to **just now · 2 ms**.

**SAY**

> Three things. `use std.io` brings in input and output — nothing is in
> scope by accident. `fn main` is where every program begins. And a
> comment is two tildes, because this language is not pretending to be
> C.
>
> `io.say` took a number without being asked to convert it. Two
> milliseconds, and that number is real — it came back from the
> compiler just now.

**ON SCREEN** Edit the code in place: change `io.say` to `io.sayy`.
Run. The panel turns red.

**SAY**

> And this is the part I would judge a language on. The code, the file,
> the line, the column, the underline — and then the six functions that
> module actually has. You are never left guessing what you were
> allowed to type.

**ON SCREEN** Fix it. Scroll to the task. Type the answer live:

```sprfst
io.say("SPRFST")
io.say(5 * 2)
```

Press **Check my answer**. Green: *that is it · +100 points*. Point at
the ring in the sidebar filling.

**SAY**

> A hundred points. There are ten of these and a thousand points in
> total, and the only way to get them is for the real compiler to print
> the right thing.

---

## 4:40 — Scene 3. Values and names  *(2m30)*

**ON SCREEN** Lesson 2. The padlock diagram.

**SAY**

> `let` is a name that will never change. `var` is one that will. The
> default is the one that cannot surprise you later.

**ON SCREEN** Run the example. Point at the third line of output:
`Text  Int  Num`.

**SAY**

> I did not write a single type, and all three have one. That is
> inference, not absence.
>
> Now the line in the middle, because this is where SPRFST disagrees
> with almost everything else: seven divided by two is three point
> five. An Int over an Int gives you a Num. Most languages throw the
> half away without telling you. If you want the whole part, you ask
> for it, and `to_int` is you asking in writing.

**ON SCREEN** Do the task on camera. +100.

---

## 7:10 — Scene 4. Choosing and repeating  *(2m30)*

**ON SCREEN** Lesson 3's diagram: both branches feeding one value.

**SAY**

> `if` is an expression. It has a value, so you can hand it straight to
> a name — which is exactly why there is no question-mark-colon
> operator. It would only be a second way of writing this.
>
> The operators are words: and, or, not. You read them aloud.

**ON SCREEN** The loop ring. Point at the two exits.

**SAY**

> Two dots is up to; three dots includes the end. `skip` goes round
> again, `break` leaves. There is also `while`, and a bare `loop` when
> you want to decide the ending yourself.

**ON SCREEN** Run it, then change `shown > 3` to `shown > 6` and run
again — six numbers come back.

**SAY**

> Everything on this page is editable. Change it, run it, see what
> happens. That is the whole point of a tour you can press.

---

## 9:40 — Scene 5. Functions  *(2m30)*

**ON SCREEN** Lesson 4. The machine diagram, then the conveyor.

**SAY**

> `give` hands the answer back. A function that is one expression drops
> the braces and uses a fat arrow.
>
> The types on the outside are not ceremony. They are the contract that
> lets the compiler tell you precisely where you went wrong three files
> away.

**ON SCREEN** Run. Point at each of the three lines in turn.

**SAY**

> Forty: `apply_twice` took `double` as an ordinary argument, because
> functions are values here. Twenty: the pipe sends a value through
> functions left to right, in the order it happens, instead of inside
> out. Seven: a function with no name at all.

---

## 12:10 — Scene 6. Text, lists, maps, sets  *(2m30)*

**ON SCREEN** Lesson 5's diagram. Point at the list cells, then the set
dropping the second "sea", then the map wiring.

**SAY**

> Four shapes. A list is in order and reachable by number. A set holds
> each thing once. A map finds a thing by its key. And text is a value
> — every one of these methods hands you a new piece of text and leaves
> yours alone.

**ON SCREEN** Run. Then point at the second-to-last line of the
program: `seen.get("sea") ?? 0`.

**SAY**

> Look at that `?? 0`. Asking a map for a key did not give me a number.
> It gave me a number *or nothing*, and I had to say what the nothing
> means. Which is the next lesson, and it is the one that matters most.

---

## 14:40 — Scene 7. Nothing, and failure  *(3m)*

**ON SCREEN** Lesson 6's diagram — the full-and-empty boxes, the gate,
the fork.

**SAY**

> A question mark on a type means *or nothing*. `Text?` is text, or
> nothing at all, and the compiler will not let you use one where plain
> text is wanted. A missing value cannot slip past you and become a
> crash an hour later.
>
> Question-mark-dot calls the method only when there is something to
> call it on. Two question marks say what the nothing becomes. Chain
> the first and finish with the second, and that is this line.

**ON SCREEN** Run. `hello` then `nothing`.

**SAY**

> Same function, two answers, no crash and no special case written by
> hand.
>
> Missing and failed are different ideas, so they get different tools.
> Something that can fail hands back a `Result`: `Ok` with the value, or
> `Err` with the reason. `match` pulls it apart and makes you deal with
> both. There are no exceptions arriving from nowhere — if a function
> can fail, you can see it at the call.

**ON SCREEN** Scroll to the enum block.

**SAY**

> And match is not only for Results. Make your own kinds with `enum`,
> each carrying whatever it needs, and the compiler will tell you when
> you have forgotten a case.

**ON SCREEN** Do the task. Take the **Hint** first, on purpose. Point at
the badge changing from *100 points* to *60 points*.

**SAY**

> Taking the hint costs you forty. Reading the answer costs seventy.
> Still worth something — typing it in and watching it run is how a lot
> of people learn — but the page keeps count honestly.

---

## 17:40 — Scene 8. Shapes of your own  *(3m)*

**ON SCREEN** Lesson 7's diagram: two counters, two points, the socket.

**SAY**

> Two counters with the same count are still two counters. Two points
> with the same numbers *are* the same point. Thing versus measurement
> — and this language gives you a different word for each. `object` has
> an identity; `data` is only its contents, and gets `==` for free.

**ON SCREEN** Run the example.

**SAY**

> A trait is a promise: these functions exist. It can also carry a
> finished method written in terms of the ones it demands — `greet` was
> written once, and a Person and a Robot both got it, with nothing in
> common but the promise.
>
> There is no inheritance here. No base class, no super, no diamond. A
> small promise kept is worth more than a family tree.

---

## 20:40 — Scene 9. Every type, one file at a time  *(2m)*

**ON SCREEN** Lesson 8's diagram.

**SAY**

> One function, every type, still fully checked. The bound after the
> colon says what you are allowed to assume — here, that the thing can
> be compared.
>
> And a module is just a file that names itself. `pub` is what gets
> out; everything else belongs to the file. No header, no export list
> at the bottom, nothing to register in a build file.

**ON SCREEN** Cut to the terminal:

```
$ sprfst new orchard
  created orchard
$ cd orchard && sprfst run .
hello from orchard
the numbers add up to 31
```

**SAY**

> A project is the same idea one size up. `src`, `tests`, `assets`,
> `packages`, and a `project.sprfst` describing it.

---

## 22:40 — Scene 10. Memory, and doing several things  *(3m)*

**ON SCREEN** Lesson 9's diagram: two names, one list.

**SAY**

> Lists, maps and objects are references. Hand one to a function and
> the function has the same one you do — nothing was copied, and the
> change you can see is the point. When you want your own, `clone` says
> so out loud, in the code, where a reader can see the cost.

**ON SCREEN** Run. Point at `finished` arriving last.

**SAY**

> `defer` runs when the function leaves, however it leaves. Close the
> file next to where you opened it and stop thinking about it.
>
> `ref` says I am only borrowing this. `own` says I am taking it, and
> the compiler stops the caller using it afterwards. No collector pause
> you can feel, and no `free` to forget.
>
> `task` is a function that can run alongside others; `spawn` starts
> one, `await` waits for the answer.

**ON SCREEN** The amber note under the example.

**SAY**

> And the honest part, which is on the page in writing: tasks run on
> real threads, but the interpreter holds one lock. This is concurrency
> for overlapping waiting, not for using eight cores at once. A native
> backend is the next big piece of work.

---

## 25:40 — Scene 11. The whole thing  *(2m)*

**ON SCREEN** Lesson 10's verb diagram.

**SAY**

> Thirteen words. That is the entire command line, and it is deliberate
> — you should be able to hold it in your head.

**ON SCREEN** Terminal, quickly:

```
$ sprfst fmt src/main.spf
  unchanged  src/main.spf
$ sprfst lint src/main.spf
  clean  1 file linted
$ sprfst test
  pass  adding  0.01ms
  bench a thousand pushes  13493 ops/s  0.074ms each
$ sprfst docs
  docs  3 pages  ->  docs/
```

**SAY**

> Formatter, linter, tests with benchmarks, documentation. In the box,
> one word each, nothing to install. A test is a block with a name; a
> bench is a block that gets timed.
>
> The package manager is called Forge. A package is a folder or a git
> URL — there is no central registry, so there is nothing to go down,
> nothing to be bought and nobody to take your name — and everything is
> locked to a SHA-256 of its contents.

**ON SCREEN** Back to the page. Run the word-count example.

**SAY**

> And this is ordinary SPRFST: a map, a loop, a lambda, interpolation,
> an optional with a default, and a sorted copy. Nothing in it is a
> trick you have not already seen.

---

## 27:40 — Scene 12. The table at the end  *(1m)*

**ON SCREEN** Scroll to the coverage table. Hold on it. Scroll slowly
through all twenty three rows.

**SAY**

> There is the promise kept. Every part of the language, and the lesson
> that taught it. If a row looks unfamiliar, that is where to go back
> to.
>
> Underneath it, the things SPRFST cannot do yet, in the same plain
> words: no standalone binary, no TLS in the runtime, one lock around
> concurrency. You would find out eventually. You may as well find out
> from me.

**ON SCREEN** Final card: the mark, then

```
sprfst run new/serve.spf     →     http://localhost:7070
```

**SAY**

> Ten lessons and a thousand points. The page is in the repository, it
> runs on your machine, and nothing it shows you comes from anywhere
> else.

---

## Appendix — a ten minute cut

Scenes 1, 2, 7 and 12. The runner turning green, the first program, the
optional-and-Result lesson, and the coverage table. Those four carry
the whole argument: it is real, it is small, it will not let a missing
value through, and nothing has been left out.

## Appendix — lower thirds

Put these up as the matching scene starts.

| scene | caption |
|---|---|
| 1 | `sprfst run new/serve.spf` |
| 2 | lesson 1 — how a program is made |
| 3 | lesson 2 — values and names |
| 4 | lesson 3 — choosing and repeating |
| 5 | lesson 4 — functions |
| 6 | lesson 5 — text, lists, maps, sets |
| 7 | lesson 6 — nothing, and failure |
| 8 | lesson 7 — shapes of your own |
| 9 | lesson 8 — every type, one file at a time |
| 10 | lesson 9 — memory, and several things |
| 11 | lesson 10 — a whole program, and the tools |
| 12 | every part of the language, and where it was taught |
