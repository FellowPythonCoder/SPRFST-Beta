# SPRFST Browser architecture

The browser is intentionally split into two small halves:

- `browser/engine` is the browser engine. It is written in SPRFST and owns
  navigation, fetching, parsing, styling, blocking, layout, caching and the
  display list.
- `browser/mac-app/Sources` is the native macOS shell. It owns the window,
  controls, tabs, scrolling, image decoding and painting. It does not parse
  HTML or run a second browser engine.

The project remains part of the repository because the compiler and runtime
are needed to build and run SPRFST. Browser-specific source and assets stay
under `browser/`, organized as `engine/`, `mac-app/`, `privacy-rules/`, `tests/`, `visuals/` and `documentation/`.

## A page's path through the engine

```text
address bar
    |
    v
page.spf             decide address or search, coordinate one page load
    |
    +--> uri.spf     parse and resolve URLs
    |
    +--> fetch.spf   HTTP, curl-backed HTTPS, redirects and response store
    |
    +--> shield.spf  block requests and cosmetic selectors before work
    |
    +--> html.spf    forgiving HTML tree and text extraction
    |
    +--> css.spf     useful selectors and visual declarations
    |
    +--> layout.spf  styled tree -> flat display list
    |
    v
main.spf             JSON service or terminal output
    |
    v
Engine.swift         line protocol; no HTML parsing
    |
    v
PageView.swift       paint text, rules, images and links
```

Searches use the same path. `page.spf` recognizes non-address text, fetches
DuckDuckGo's plain HTML endpoint, and `search.spf` turns the result anchors
into a native result page. The first provider result's snippet becomes the
overview; the destination URL is decoded and placed on ordinary links.

When Node.js is available, `javascript.spf` sends classic inline and external
scripts to `javascript-runner.js`. The helper uses a short-lived, restricted
Node VM with a small DOM surface, limits external scripts to eight resources
and one megabyte each, and gives each script 250 milliseconds. This is a
compatibility enhancement, not a replacement for the SPRFST parser or layout
engine. Pages that need a complete browser DOM continue with HTML, CSS and
`noscript` fallbacks.

## Module guide

| Module | Responsibility |
|---|---|
| `uri.spf` | URL parsing, host detection, relative URL resolution |
| `fetch.spf` | HTTP/1.1 socket fetching, curl HTTPS fallback, redirects, cache |
| `shield.spf` | host/path blocking, cosmetic hiding, request counters |
| `html.spf` | malformed-but-useful HTML parsing, entities, text and links |
| `css.spf` | selector matching, colours, font and spacing declarations |
| `layout.spf` | Helvetica-compatible text measurement and display-list layout |
| `search.spf` | provider-result extraction, URL decoding and search presentation |
| `reader.spf` | article-focused reading lens |
| `page.spf` | orchestration and internal `sprfst://` pages |
| `main.spf` | terminal renderer and newline-delimited JSON service |

## Speed work

The main optimization rule is to avoid work that cannot affect the visible
page. The Shield runs before subresources are fetched, the response store
serves revisits, up to four uncached stylesheets are fetched concurrently with
SPRFST tasks, and native C-backed text search avoids repeated temporary slices
in hot parser loops. The macOS painter caches images and only hit-tests known
links.

The service reports fetch, parse, style and layout timings for every response.
Those measurements are more useful than a universal promise: a local article,
a TLS connection, a JavaScript application and a large image-heavy page have
very different costs. The browser does not claim that every website loads in
one second or that it supports every modern web feature.

## Build and test

From the repository root:

```sh
make
./tests/run_tests.sh
cd browser && ../build/bin/sprfst test
```

On macOS, package the native application with:

```sh
./tools/build_browser_app.sh --install
```

The packager copies `browser/engine/*.spf`, the Shield rules, the interpreter and
this browser documentation into the application resources. The browser code
is therefore visible and inspectable in the finished project rather than
hidden behind a web view.
