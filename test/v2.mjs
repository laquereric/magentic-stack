#!/usr/bin/env node
// V2 hydration gate. Three explicit refuse cases + a matching join proof.
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
  try { return require(join(here, "node_modules/jsdom")); } catch { /* next */ }
  try { return require("jsdom"); } catch { /* next */ }
  throw new Error("jsdom not found; cd test && npm install");
}

const { JSDOM } = loadJsdom();

function bootFixture(name) {
  const html = readFileSync(join(root, "test-fixtures", name), "utf8")
    .replace(/<script src="[^"]+"><\/script>/, "");
  const dom = new JSDOM(html, { runScripts: "dangerously", url: "https://example.test/v2" });
  const { window } = dom;
  window.eval(js);
  if (window.document.readyState === "loading") {
    window.document.dispatchEvent(new window.Event("DOMContentLoaded", { bubbles: true }));
  }
  return window;
}

function renderText(window) {
  const rootEl = window.document.querySelector(".ux-render-root");
  return rootEl ? rootEl.textContent : "";
}

function assertNotInvented(window, canaries) {
  const text = renderText(window);
  for (const c of canaries) {
    assert.equal(text.includes(c), false, "must not invent " + c + " into the render tree");
  }
  const hydrated = window.document.querySelectorAll("[data-vv-hydrated]");
  assert.equal(hydrated.length, 0, "must not hydrate");
  assert.equal(window.VvHtmlComponents.payloadFor("shell-001"), null);
}

{
  const window = bootFixture("profile9-title-only.html");
  assert.equal(window.VvHtmlComponents.gate().reason, "no-block");
  assert.equal(window.VvHtmlComponents.gate().ok, false);
  assertNotInvented(window, ["CANARY-REMEDIATION-TEXT", "INVENTED-BODY", "INVENTED-REASON"]);
  console.log("ok NO BLOCK — no invent, no throw");
}

{
  const window = bootFixture("profile9-malformed-jsonld.html");
  assert.equal(window.VvHtmlComponents.gate().reason, "malformed");
  assert.equal(window.VvHtmlComponents.gate().ok, false);
  assertNotInvented(window, ["CANARY-REMEDIATION-TEXT"]);
  assert.ok(window.document.querySelector("[data-ux-label]").textContent.includes("Governance"));
  console.log("ok MALFORMED BLOCK — refuse all hydration, page readable");
}

{
  const window = bootFixture("profile9-missing-rootnode.html");
  assert.equal(window.VvHtmlComponents.gate().reason, "malformed");
  assert.equal(window.VvHtmlComponents.gate().ok, false);
  assertNotInvented(window, ["CANARY-REMEDIATION-TEXT"]);
  console.log("ok missing document.rootNode — refuse, no partial hydrate");
}

{
  const window = bootFixture("profile9-digest-mismatch.html");
  assert.equal(window.VvHtmlComponents.gate().reason, "mismatch");
  assert.equal(window.VvHtmlComponents.gate().ok, false);
  assertNotInvented(window, ["CANARY-MISMATCH-BODY", "CANARY-MISMATCH-REASON"]);
  assert.ok(window.document.querySelector("[data-ux-label]").textContent.includes("Governance"));
  console.log("ok DIGEST MISMATCH — refuse rather than hydrate the wrong document");
}

{
  const window = bootFixture("profile9-inline-jsonld.html");
  assert.equal(window.VvHtmlComponents.gate().ok, true);
  const shell = window.document.querySelector('[data-ux-node-id="shell-001"]');
  const refusal = window.document.querySelector('[data-ux-node-id="refusal-001"]');
  assert.equal(shell.getAttribute("data-vv-hydrated"), "true");
  assert.equal(window.VvHtmlComponents.payloadFor("shell-001").title, "Heat Alert Map Activation");
  assert.equal(window.VvHtmlComponents.payloadFor(refusal).reason, "UX_EFFECT_AFFORDANCE_DENIED");
  assert.equal(window.VvHtmlComponents.payloadFor(refusal).overridePolicy, "none");
  assert.equal(window.VvHtmlComponents.payloadFor("list-001")["ordered-scope"], "harbor-district");
  assert.equal(renderText(window).includes("CANARY-REMEDIATION-TEXT"), false, "V2 must not render payload visually");
  const article = window.document.querySelector("article");
  assert.equal(article.parentNode.tagName, "UL");
  console.log("ok matching block — join by nodeId, no visual payload, no reparent");
}

console.log("V2 ok");
