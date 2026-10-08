/* =====================================================================
   SPRFST — the tour, in a browser.

   This file paints and keeps score. It does not run SPRFST: there is
   no interpreter here and no table of stored answers. Pressing Run
   sends what you typed to new/serve.spf, which writes it to a file and
   gives it to the real compiler, and what comes back is what your
   program printed. With the runner off, the page says so and shows the
   output that was recorded when these examples were written.
   ===================================================================== */
(function () {
    "use strict";

    var RUNNER = false;
    var MOST = 1000;                       // ten lessons, a hundred each
    var KEY = "sprfst.tour.web.v1";

    /* ------------------------------------------------------------ store */
    function load() {
        try {
            var raw = localStorage.getItem(KEY);
            if (!raw) return { won: {}, hinted: {}, shown: {} };
            var kept = JSON.parse(raw);
            return {
                won: kept.won || {},
                hinted: kept.hinted || {},
                shown: kept.shown || {}
            };
        } catch (e) {
            return { won: {}, hinted: {}, shown: {} };
        }
    }
    function save() {
        try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) {}
    }
    var state = load();

    function worth(n) {
        if (state.shown[n]) return 30;
        if (state.hinted[n]) return 60;
        return 100;
    }
    function total() {
        var sum = 0;
        for (var n in state.won) { if (state.won[n]) sum += state.won[n]; }
        return sum;
    }
    function rankOf(points) {
        if (points >= 950) return "Pro";
        if (points >= 700) return "Craftsman";
        if (points >= 450) return "Builder";
        if (points >= 200) return "Apprentice";
        return "Newcomer";
    }

    /* ------------------------------------------------------- highlighter */
    var WORDS = ("use|fn|let|var|give|if|else|for|while|loop|skip|break|match|when|" +
                 "object|data|trait|impl|enum|task|spawn|await|defer|pub|module|test|" +
                 "bench|ref|own|in|and|or|not|self|nil|true|false|clone|unsafe|as").split("|");
    var TYPES = ("Int|Num|Text|Bool|Nil|Any|Map|Result|Ok|Err|Ord|Eq|Self").split("|");

    var LEX = new RegExp(
        "(~~[^\\n]*)" +                                   // 1 comment
        "|(\"(?:[^\"\\\\\\n]|\\\\.)*\")" +                // 2 text
        "|\\b(\\d+\\.\\d+|\\d+)\\b" +                     // 3 number
        "|\\b(" + WORDS.join("|") + ")\\b" +              // 4 keyword
        "|\\b(" + TYPES.join("|") + ")\\b" +              // 5 type
        "|([A-Za-z_][A-Za-z0-9_]*)(?=\\s*\\()",           // 6 call
        "g");

    function escape(text) {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function paint(source) {
        var out = "", last = 0, m;
        LEX.lastIndex = 0;
        while ((m = LEX.exec(source)) !== null) {
            out += escape(source.slice(last, m.index));
            var cls = m[1] ? "t-com" : m[2] ? "t-str" : m[3] ? "t-num"
                    : m[4] ? "t-key" : m[5] ? "t-type" : "t-fn";
            out += '<span class="' + cls + '">' + escape(m[0]) + "</span>";
            last = m.index + m[0].length;
        }
        out += escape(source.slice(last));
        return out + "\n";
    }

    /* ----------------------------------------------------- the editors */
    function wire(edit) {
        var area = edit.querySelector("textarea");
        var code = edit.querySelector("pre.paint code");
        if (!area || !code) return;

        function redraw() { code.innerHTML = paint(area.value); }
        redraw();

        area.addEventListener("input", redraw);
        area.addEventListener("scroll", function () {
            var pre = edit.querySelector("pre.paint");
            pre.scrollTop = area.scrollTop;
            pre.scrollLeft = area.scrollLeft;
        });
        // Tab indents by four, as the formatter does.
        area.addEventListener("keydown", function (event) {
            if (event.key === "Tab") {
                event.preventDefault();
                var at = area.selectionStart;
                area.value = area.value.slice(0, at) + "    " + area.value.slice(area.selectionEnd);
                area.selectionStart = area.selectionEnd = at + 4;
                redraw();
            }
            if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
                event.preventDefault();
                var block = edit.closest(".code");
                var task = edit.closest(".task");
                var button = task ? task.querySelector(".check")
                                  : (block ? block.querySelector(".run") : null);
                if (button) button.click();
            }
        });
        // Match the box to the code it was given.
        var lines = area.value.split("\n").length;
        area.style.height = Math.max(edit.classList.contains("tall") ? 210 : 120,
                                     lines * 22 + 34) + "px";
    }

    /* -------------------------------------------------------- the runner */
    function tell(on, detail) {
        RUNNER = on;
        var strip = document.getElementById("live");
        strip.classList.toggle("on", on);
        document.getElementById("livetext").textContent = on
            ? "runner on — your code really compiles"
            : (detail || "reading only — runner is off");
        strip.title = on
            ? "Code on this page is run by the SPRFST interpreter on your machine"
            : "Start it with:  sprfst run new/serve.spf";
    }

    function greet() {
        fetch("api/hello", { cache: "no-store" })
            .then(function (r) { return r.ok ? r.json() : null; })
            .then(function (shape) {
                if (shape && shape.ok) tell(true);
                else tell(false);
            })
            .catch(function () { tell(false); });
    }

    function run(code, then) {
        if (!RUNNER) { then(null); return; }
        fetch("api/run", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ code: code })
        })
            .then(function (r) { return r.ok ? r.json() : null; })
            .then(function (shape) {
                if (!shape || !shape.ok) { then(null); return; }
                then({ lines: shape.lines || [], broke: !!shape.broke, ms: shape.ms || 0 });
            })
            .catch(function () { tell(false); then(null); });
    }

    function tidy(lines) {
        var out = lines.slice();
        while (out.length && out[out.length - 1].trim() === "") out.pop();
        return out;
    }
    function alike(got, want) {
        if (got.length !== want.length) return false;
        for (var i = 0; i < got.length; i++) {
            if (got[i].trim() !== want[i].trim()) return false;
        }
        return true;
    }

    function show(where, lines, kind, note) {
        where.className = "out" + (kind ? " " + kind : "");
        var tag = document.createElement("span");
        tag.className = "tag";
        tag.textContent = note;
        where.textContent = lines.join("\n");
        where.prepend(tag);
    }

    /* ------------------------------------------------------- the examples */
    function setupExample(block) {
        var area = block.querySelector("textarea");
        var out = block.querySelector(".out");
        var button = block.querySelector(".run");
        var recorded = (out.getAttribute("data-recorded") || "").split("\n");

        show(out, recorded, "", "recorded output");

        button.addEventListener("click", function () {
            if (!RUNNER) {
                show(out, recorded.concat(["", "— that is the recorded output. To run this for real:",
                                           "     sprfst run new/serve.spf"]),
                     "", "runner is off");
                return;
            }
            button.disabled = true;
            button.textContent = "running…";
            run(area.value, function (answer) {
                button.disabled = false;
                button.textContent = "Run";
                if (!answer) { show(out, ["the runner did not answer"], "bad", "trouble"); return; }
                show(out, answer.lines.length ? answer.lines : ["(it printed nothing)"],
                     answer.broke ? "bad" : "live",
                     answer.broke ? "your compiler says" : "just now · " + answer.ms + " ms");
            });
        });
    }

    /* ---------------------------------------------------------- the tasks */
    function setupTask(task) {
        var n = parseInt(task.getAttribute("data-task"), 10);
        var want = tidy((task.getAttribute("data-expect") || "").split("\n"));
        var area = task.querySelector("textarea");
        var out = task.querySelector(".out");
        var verdict = task.querySelector(".verdict");
        var hintText = task.querySelector(".hinttext").textContent;
        var answerText = task.querySelector(".answertext").textContent;
        var worthTag = task.querySelector(".worth");

        function keep() {
            try { localStorage.setItem(KEY + ".code." + n, area.value); } catch (e) {}
        }
        try {
            var kept = localStorage.getItem(KEY + ".code." + n);
            if (kept) area.value = kept;
        } catch (e) {}
        area.addEventListener("input", keep);

        function retag() {
            worthTag.textContent = state.won[n] ? state.won[n] + " points won"
                                                : worth(n) + " points";
        }
        retag();
        if (state.won[n]) {
            verdict.className = "verdict yes";
            verdict.textContent = "finished";
        }

        task.querySelector(".hint").addEventListener("click", function () {
            if (!state.won[n]) { state.hinted[n] = true; save(); retag(); }
            show(out, [hintText], "", "hint · this one is now worth " + worth(n));
        });

        task.querySelector(".reveal").addEventListener("click", function () {
            if (!state.won[n]) { state.shown[n] = true; save(); retag(); }
            area.value = answerText;
            area.dispatchEvent(new Event("input"));
            show(out, ["one way to do it is now in the box — press Check my answer"], "",
                 "shown · this one is now worth " + worth(n));
        });

        task.querySelector(".runtask").addEventListener("click", function () {
            if (!RUNNER) { offer(out); return; }
            run(area.value, function (answer) {
                if (!answer) { show(out, ["the runner did not answer"], "bad", "trouble"); return; }
                show(out, answer.lines.length ? answer.lines : ["(it printed nothing)"],
                     answer.broke ? "bad" : "live", answer.broke ? "your compiler says" : "it printed");
            });
        });

        task.querySelector(".check").addEventListener("click", function () {
            if (!RUNNER) { offer(out); return; }
            verdict.className = "verdict";
            verdict.textContent = "checking…";
            run(area.value, function (answer) {
                if (!answer) {
                    verdict.textContent = "";
                    show(out, ["the runner did not answer"], "bad", "trouble");
                    return;
                }
                var got = tidy(answer.lines);
                if (answer.broke) {
                    verdict.className = "verdict no";
                    verdict.textContent = "it did not compile";
                    show(out, got, "bad", "your compiler says");
                    return;
                }
                if (alike(got, want)) {
                    var first = !state.won[n];
                    if (first) {
                        state.won[n] = worth(n);
                        save();
                        retag();
                        award(state.won[n]);
                    }
                    verdict.className = "verdict yes";
                    verdict.textContent = first ? "that is it  ·  +" + state.won[n] + " points"
                                                : "that is it";
                    show(out, got, "live", "just now · " + answer.ms + " ms");
                    draw();
                    return;
                }
                var line = 1;
                for (var i = 0; i < want.length; i++) {
                    var mine = i < got.length ? got[i].trim() : "";
                    if (mine !== want[i].trim()) { line = i + 1; break; }
                }
                verdict.className = "verdict no";
                verdict.textContent = "not yet — line " + line + " is the first difference";
                show(out, ["you printed"]
                        .concat(got.length ? got.map(function (l) { return "   " + l; })
                                           : ["   (nothing)"])
                        .concat([""], ["the lesson wants"],
                                want.map(function (l) { return "   " + l; })),
                     "", "compared line by line");
            });
        });
    }

    function offer(out) {
        show(out, ["Checking needs the runner, and the runner is off.",
                   "",
                   "In the project folder:",
                   "     sprfst run new/serve.spf",
                   "",
                   "then open  http://localhost:7070  and press Check again.",
                   "Your code is run by the real compiler on this machine — never anywhere else."],
             "", "runner is off");
    }

    /* --------------------------------------------------------- the score */
    function draw() {
        var points = total();
        var done = Object.keys(state.won).length;
        document.getElementById("points").textContent = points;
        document.getElementById("rank").textContent = rankOf(points) + " · " + done + " of 10";
        var round = 2 * Math.PI * 19;
        document.getElementById("ring").setAttribute(
            "stroke-dasharray", (round * Math.min(1, points / MOST)).toFixed(1) + " " + round.toFixed(1));
        document.querySelectorAll("#nav a").forEach(function (link) {
            link.classList.toggle("won", !!state.won[link.getAttribute("data-n")]);
        });
    }

    var waiting;
    function award(points) {
        var toast = document.getElementById("toast");
        toast.textContent = "+" + points + " points";
        toast.classList.add("up");
        clearTimeout(waiting);
        waiting = setTimeout(function () { toast.classList.remove("up"); }, 1800);
    }

    /* ----------------------------------------------------------- the rail */
    var GROUPS = { 1: "The beginning", 2: "The basics", 4: "Building blocks",
                   6: "The important one", 7: "Structure", 9: "Underneath", 10: "All of it" };

    function buildNav() {
        var nav = document.getElementById("nav");
        document.querySelectorAll("section.lesson").forEach(function (section) {
            var n = section.getAttribute("data-n");
            if (GROUPS[n]) {
                var head = document.createElement("div");
                head.className = "group";
                head.textContent = GROUPS[n];
                nav.appendChild(head);
            }
            var link = document.createElement("a");
            link.href = "#" + section.id;
            link.setAttribute("data-n", n);
            link.innerHTML = '<span class="tick">✓</span><span class="num">' + n +
                             '</span><span>' + section.getAttribute("data-title") + "</span>";
            nav.appendChild(link);
        });
        var end = document.createElement("a");
        end.href = "#finish";
        end.setAttribute("data-n", "end");
        end.innerHTML = '<span class="tick"></span><span class="num"></span><span>What this covers</span>';
        nav.appendChild(end);
    }

    function spy() {
        var marks = [].slice.call(document.querySelectorAll("section.lesson, #finish"));
        var seen = null;
        window.addEventListener("scroll", function () {
            var best = null;
            marks.forEach(function (one) {
                if (one.getBoundingClientRect().top <= 140) best = one;
            });
            if (!best || best === seen) return;
            seen = best;
            document.querySelectorAll("#nav a").forEach(function (link) {
                link.classList.toggle("here", link.getAttribute("href") === "#" + best.id);
            });
        }, { passive: true });
    }

    /* ------------------------------------------------------------- start */
    document.querySelectorAll(".edit").forEach(wire);
    document.querySelectorAll(".code[data-example]").forEach(setupExample);
    document.querySelectorAll(".task").forEach(setupTask);
    buildNav();
    spy();
    draw();
    greet();
    setInterval(greet, 15000);
})();
