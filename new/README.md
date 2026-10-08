# new/ — the tour in a browser

Ten lessons that cover the whole language, as one page you can press.

```
sprfst run new/serve.spf
```

then open **http://localhost:7070**.

The dot in the sidebar turns green when the runner is on. From then
on, every **Run** and every **Check my answer** sends what you typed to
`serve.spf`, which writes it to a file in your temporary folder and
hands it to the real compiler. What you see is what your program
printed. There is no SPRFST interpreter in the browser and no table of
stored answers anywhere.

Without the server the page is still worth reading: every example
shows the output that was recorded when it was written, labelled as
such, and the Run buttons tell you how to turn the runner on rather
than pretending.

## What is here

| file | |
|---|---|
| `index.html` | the ten lessons, their diagrams, and the tasks |
| `tour.css` | the look — deep black, one warm accent, handwriting for headings |
| `tour.js` | highlighting, scoring, and talking to the runner. It paints and keeps score; it never runs SPRFST |
| `serve.spf` | the runner: serves these three files and compiles what you type |
| `VIDEO-SCRIPT.md` | a shooting script for a video of this page, about 28 minutes |

## Points

A hundred a lesson, a thousand in all. Taking the hint drops that
lesson to sixty, reading the answer drops it to thirty. Five ranks,
Newcomer to Pro. Your score and your code are kept in the browser's
local storage, on your machine — clearing site data starts you over.

## Is it true?

Every example output on the page and every answer behind a *Show me*
button was produced by running it. To check that for yourself while
the server is up:

```
curl -s -X POST localhost:7070/api/run \
     -H 'Content-Type: application/json' \
     -d '{"code":"use std.io\n\nfn main() { io.say(2 + 2) }"}'
```

## The other two tours

| | |
|---|---|
| a Mac app, 26 smaller steps | `make tour` |
| a terminal, the same 26 | `sprfst run learn/tour.spf` |
| this one, 10 lessons, visual | `sprfst run new/serve.spf` |

All three hand your code to the same compiler.
