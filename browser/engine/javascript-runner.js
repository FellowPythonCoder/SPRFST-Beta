const fs = require("node:fs");
const vm = require("node:vm");

(async () => {
  const input = process.argv[2];
  const base = process.argv[3] || "about:blank";
  if (!input) process.exit(2);

  const source = fs.readFileSync(input, "utf8");
  const writes = [];
  let bodyMarkup = null;

  function node(tag) {
    let content = "";
    return {
      tagName: String(tag || "div").toUpperCase(),
      textContent: "",
      value: "",
      style: {},
      children: [],
      setAttribute() {},
      appendChild(child) {
        this.children.push(child);
      },
      get innerHTML() { return content; },
      set innerHTML(value) { content = String(value); },
      get outerHTML() {
        return content || this.textContent || "";
      }
    };
  }

  const body = {
    appendChild(child) {
      const html = child && child.outerHTML ? child.outerHTML : "";
      if (html) bodyMarkup = (bodyMarkup || "") + html;
    },
    get innerHTML() { return bodyMarkup || ""; },
    set innerHTML(value) { bodyMarkup = String(value); }
  };

  const document = {
    body,
    documentElement: { classList: { add() {}, remove() {} } },
    title: "",
    write(value) { writes.push(String(value)); },
    writeln(value) { writes.push(String(value) + "\n"); },
    createElement: node,
    createTextNode(value) { return { outerHTML: String(value) }; },
    getElementById() { return null; },
    querySelector() { return null; },
    querySelectorAll() { return []; },
    addEventListener() {}
  };

  const context = {
    document,
    window: null,
    globalThis: null,
    location: new URL(base),
    navigator: { userAgent: "SPRFST Browser" },
    console: { log() {}, warn() {}, error() {} },
    URL,
    setTimeout() { return 0; },
    clearTimeout() {},
    setInterval() { return 0; },
    clearInterval() {}
  };
  context.window = context;
  context.globalThis = context;

  const pattern = /<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi;
  const external = [];
  const inline = [];
  let match;
  while ((match = pattern.exec(source)) !== null) {
    const attrs = match[1] || "";
    const code = match[2] || "";
    if (/\btype\s*=\s*["']?(?:application\/json|importmap|module)/i.test(attrs)) continue;
    const srcMatch = attrs.match(/\bsrc\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))/i);
    if (srcMatch) {
      const src = srcMatch[1] || srcMatch[2] || srcMatch[3];
      try { external.push(new URL(src, base).href); } catch (_) {}
    } else if (code.trim()) {
      inline.push(code);
    }
  }

  const downloaded = [];
  for (let start = 0; start < external.length; start += 8) {
    const batch = await Promise.all(external.slice(start, start + 8).map(async (url) => {
      try {
        if (url.startsWith("file:")) {
          const text = fs.readFileSync(new URL(url), "utf8");
          return text.length <= 1000000 ? text : "";
        }
        const response = await fetch(url, { signal: AbortSignal.timeout(3000) });
        if (!response.ok) return "";
        const text = await response.text();
        return text.length <= 1000000 ? text : "";
      } catch (_) {
        return "";
      }
    }));
    downloaded.push(...batch);
  }

  for (const code of downloaded.concat(inline)) {
    if (!code.trim()) continue;
    try {
      vm.runInNewContext(code, context, { timeout: 250 });
    } catch (_) {}
  }

  let output = source;
  if (bodyMarkup !== null) {
    output = output.replace(/<body\b[^>]*>[\s\S]*?<\/body\s*>/i,
      (bodyTag) => bodyTag.replace(/>[\s\S]*?<\/body\s*>/i, ">" + bodyMarkup + "</body>"));
  }
  if (writes.length) {
    const insertion = writes.join("");
    output = output.replace(/<body\b([^>]*)>/i, "<body$1>" + insertion);
  }
  process.stdout.write(output);
})();
