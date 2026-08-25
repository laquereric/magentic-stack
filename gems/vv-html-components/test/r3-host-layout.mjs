#!/usr/bin/env node
// R3: host layout projection. Does NOT use vv-html-components as a layout engine.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const hostJs = readFileSync(
  "/Users/ericlaquer/NoIcloud/magentic-stack/gems/rails-osi-level-8/data/osi-level-8/ux-host-layout.js",
  "utf8"
);
const vvJs = readFileSync(join(here, "../dist/vv-html-components.js"), "utf8");

assert.equal(/layoutKind/.test(vvJs), false,
  "vv-html-components must not read layoutKind");

function loadJsdom() {
  const require = createRequire(import.meta.url);
  const candidates = [join(here, "node_modules/jsdom"), "jsdom"];
  for (const c of candidates) {
    try { return require(c); } catch { /* next */ }
  }
  throw new Error("jsdom not found; cd test && npm install");
}
const { JSDOM } = loadJsdom();

function page(digest, extra = {}) {
  const cols = ["c1", "c2", "c3", "c4", "c5"].map((id) =>
    `<article data-ux-node-id="${id}" data-ux-node-cid="cid:node:${id}" data-ux-acia-digest="${digest}" data-ux-component-kind="PanelFrame"><span data-ux-label>${id}</span></article>`
  ).join("");
  const children = ["c1", "c2", "c3", "c4", "c5"].map((id) =>
    ({ nodeId: id, componentKind: "PanelFrame", slt: { layoutKind: "stack", layoutArity: "one", responsiveSignature: "default" }, children: [] })
  );
  const doc = {
    correlation: "corr-r3",
    aciaDigest: extra.pkgDigest || digest,
    document: {
      rootNode: {
        nodeId: "brd-board-1",
        componentKind: "PanelFrame",
        slt: {
          layoutKind: "grid",
          layoutArity: "many",
          responsiveSignature: extra.signature || "p9.r1.grid.board-5"
        },
        children
      }
    }
  };
  return `<!doctype html><html><head></head><body>
<div class="ux-render-root" data-ux-correlation="corr-r3" data-ux-acia-digest="${digest}">
<main data-ux-node-id="brd-board-1" data-ux-node-cid="cid:node:board" data-ux-acia-digest="${digest}" data-ux-component-kind="PanelFrame">
<span data-ux-label>Board projection</span>${cols}
</main>
</div>
<script type="application/ld+json" data-ux-acia-document>${JSON.stringify(doc)}</script>
</body></html>`;
}

function boot(html) {
  const dom = new JSDOM(html, { url: "https://example.test/r3", pretendToBeVisual: true, runScripts: "dangerously" });
  const script = dom.window.document.createElement("script");
  script.textContent = hostJs;
  (dom.window.document.head || dom.window.document.documentElement).appendChild(script);
  return dom.window;
}

{
  const window = boot(page("sha256:abc"));
  const result = window.UxHostLayout.apply(window.document);
  assert.equal(Array.from(result.applied).join(","), "brd-board-1");
  const css = window.document.getElementById("ux-host-layout-rules").textContent;
  assert.match(css, /repeat\(5/);
  assert.match(css, /max-width:48rem/);
  assert.match(css, /display:block/);
  const board = window.document.querySelector('[data-ux-node-id="brd-board-1"]');
  const kids = [...board.children];
  assert.equal(kids[0].getAttribute("data-ux-label") !== null || kids[0].hasAttribute("data-ux-label"), true);
  assert.equal(kids[1].parentNode, board, "must not reparent");
  assert.ok(!board.hasAttribute("data-ux-layout-kind"));
  console.log("ok board-5 applies scoped grid and does not reparent");
}

{
  const window = boot(page("sha256:abc", { pkgDigest: "sha256:other" }));
  const result = window.UxHostLayout.apply(window.document);
  assert.equal(result.reason, "mismatch");
  assert.equal(result.applied.length, 0);
  const style = window.document.getElementById("ux-host-layout-rules");
  assert.equal(!style || style.textContent === "", true);
  console.log("ok digest mismatch applies no layout");
}

{
  const window = boot(`<!doctype html><html><body><p>plain</p></body></html>`);
  const result = window.UxHostLayout.apply(window.document);
  assert.equal(result.reason, "no-document");
  console.log("ok no ACIA document applies no layout");
}

{
  const w = boot("<!doctype html><html><body></body></html>");
  const d = w.UxHostLayout.decide;
  assert.equal(d("grid", "many", "p9.r1.grid.board-5", 5).apply, true);
  assert.equal(d("grid", "many", "p9.r1.grid.board-5", 3).apply, false);
  assert.equal(d("grid", "many", "default", 5).apply, false);
  console.log("ok recipe refuses squeeze (3-child board-5) and default flow");
}

console.log("ok r3 host layout");
