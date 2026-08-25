#!/usr/bin/env node
// V1 degradation + upgrade tests. Uses jsdom when available (npx -p jsdom).
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const js = readFileSync(join(root, "dist/vv-html-components.js"), "utf8");

function loadJsdom() {
  const require = createRequire(import.meta.url);
  const candidates = [join(here, "node_modules/jsdom"), "jsdom"];
  for (const c of candidates) {
    try {
      return require(c);
    } catch {
      /* try next */
    }
  }
  throw new Error("jsdom not found; cd test && npm install");
}

const { JSDOM } = loadJsdom();

function boot(html) {
  const dom = new JSDOM(html, {
    runScripts: "dangerously",
    url: "https://example.test/v1",
    pretendToBeVisual: true
  });
  const { window } = dom;
  window.eval(js);
  if (window.document.readyState === "loading") {
    window.document.dispatchEvent(new window.Event("DOMContentLoaded", { bubbles: true }));
  }
  if (window.__vvDefineError) {
    throw new Error("define failed: " + window.__vvDefineError);
  }
  return window;
}

function attrOrder(el) {
  return el.getAttributeNames().filter((n) => n.startsWith("data-ux-"));
}

{
  const window = boot(`<!doctype html><html><head></head><body></body></html>`);
  assert.ok(window.customElements.get("vv-component-runtime"), "runtime custom element registered");
  assert.equal(window.document.querySelectorAll("vv-component-runtime").length, 1);
  assert.ok(window.document.getElementById("vv-html-components-tokens"), "token stylesheet injected");
  const css = window.document.getElementById("vv-html-components-tokens").textContent;
  assert.match(css, /prefers-color-scheme:\s*dark/);
  assert.match(css, /--vv-canvas/);
  assert.equal(window.VvHtmlComponents.kinds.length, 19);
  console.log("ok empty page does not throw");
}

{
  const html = readFileSync(join(root, "test-fixtures/profile9-unknown-kind.html"), "utf8")
    .replace(/<script src="[^"]+"><\/script>/, "");
  const window = boot(html);
  const mystery = window.document.querySelector('[data-ux-component-kind="MysteryKind"]');
  const shell = window.document.querySelector('[data-ux-component-kind="PageShell"]');
  const banner = window.document.querySelector('[data-ux-component-kind="ContextBanner"]');
  assert.equal(mystery.getAttribute("data-vv-kind"), null, "unknown 20th kind is not adapted");
  assert.equal(shell.getAttribute("data-vv-kind"), "PageShell");
  assert.equal(banner.getAttribute("data-vv-kind"), "ContextBanner");
  console.log("ok unknown 20th kind does not break known adapters");
}

{
  const html = readFileSync(join(root, "test-fixtures/profile9-title-only.html"), "utf8")
    .replace(/<script src="[^"]+"><\/script>/, "");
  const window = boot(html);
  const list = window.document.querySelector('[data-ux-component-kind="DataList"]');
  const article = list.querySelector("article");
  assert.equal(article.parentNode, list, "must not reparent ul>article");
  assert.equal(article.tagName, "ARTICLE");
  const before = ["data-ux-node-cid", "data-ux-node-id", "data-ux-component-kind",
    "data-ux-acia-digest", "data-ux-token-digest", "data-ux-content-role"];
  assert.deepEqual(attrOrder(list).slice(0, before.length), before);
  console.log("ok DataList does not reparent article children or reorder data-ux-*");
}

{
  const html = readFileSync(join(root, "test-fixtures/profile9-no-include.html"), "utf8");
  const dom = new JSDOM(html);
  const main = dom.window.document.querySelector("[data-ux-component-kind]");
  assert.ok(main);
  assert.equal(main.getAttribute("data-ux-component-kind"), "PageShell");
  assert.equal(dom.window.document.querySelector("vv-component-runtime"), null);
  console.log("ok include absent leaves original markup");
}

console.log("V1 ok");
