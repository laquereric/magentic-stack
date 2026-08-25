#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const js = readFileSync(join(root, "dist/vv-html-components.js"), "utf8");
const require = createRequire(import.meta.url);
const { JSDOM } = require(join(here, "node_modules/jsdom"));

function boot(pkg, bodyHtml) {
  const live = new JSDOM("<!doctype html><html><head></head><body></body></html>", {
    runScripts: "dangerously",
    url: "https://example.test/v3"
  });
  if (pkg) {
    const s = live.window.document.createElement("script");
    s.setAttribute("type", "application/ld+json");
    s.setAttribute("data-ux-acia-document", "");
    s.textContent = JSON.stringify(pkg);
    live.window.document.head.appendChild(s);
  }
  live.window.document.body.innerHTML = bodyHtml;
  live.window.eval(js);
  if (live.window.document.readyState === "loading") {
    live.window.document.dispatchEvent(new live.window.Event("DOMContentLoaded", { bubbles: true }));
  }
  return live.window;
}

const digest = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const tree = `
<div class="ux-render-root" data-ux-correlation="corr-v3" data-ux-acia-digest="${digest}">
  <main data-ux-node-cid="cid:node:shell" data-ux-node-id="shell-001"
        data-ux-component-kind="PageShell" data-ux-acia-digest="${digest}"
        data-ux-token-digest="sha256:bbb" data-ux-content-role="context" aria-label="Review">
    <span data-ux-label>Review</span>
    <ul data-ux-node-cid="cid:node:list" data-ux-node-id="list-001"
        data-ux-component-kind="DataList" data-ux-acia-digest="${digest}"
        data-ux-token-digest="sha256:bbb" data-ux-content-role="evidence" aria-label="Records">
      <span data-ux-label>Records</span>
      <article data-ux-node-cid="cid:node:row" data-ux-node-id="row-001"
               data-ux-component-kind="DrillDownCard" data-ux-acia-digest="${digest}"
               data-ux-token-digest="sha256:bbb" data-ux-content-role="evidence" aria-label="Row">
        <span data-ux-label>Row</span>
      </article>
    </ul>
  </main>
</div>`;

{
  const pkg = {
    correlation: "corr-v3",
    aciaDigest: digest,
    document: {
      rootNode: {
        nodeId: "shell-001",
        componentKind: "PageShell",
        props: {
          valueJson: {
            title: "Review",
            heading: "Dossier",
            body: "CANARY-BODY-TEXT",
            unused: "CANARY-UNUSED-KEY"
          }
        },
        children: [
          {
            nodeId: "list-001",
            componentKind: "DataList",
            props: { valueJson: { heading: "Records", references: ["https://ex/ref-1"] } }
          }
        ]
      }
    }
  };
  const window = boot(pkg, tree);
  const shell = window.document.querySelector('[data-ux-node-id="shell-001"]');
  const list = window.document.querySelector('[data-ux-node-id="list-001"]');
  const article = list.querySelector("article");
  const text = window.document.querySelector(".ux-render-root").textContent;
  assert.equal(window.VvHtmlComponents.gate().ok, true);
  assert.equal(shell.getAttribute("data-vv-kind"), "PageShell");
  assert.ok(shell.className.includes("vv-pageshell"));
  assert.ok(text.includes("CANARY-BODY-TEXT"), "consumed body must render");
  assert.equal(text.includes("CANARY-UNUSED-KEY"), false, "unconsumed key must not invent");
  assert.equal(text.includes("N/A"), false);
  assert.equal(article.parentNode, list, "must not reparent ul>article");
  assert.equal(shell.querySelector("[data-vv-generated][aria-label]"), null);
  assert.equal(window.document.querySelector("vv-component-runtime").shadowRoot, null);
  console.log("ok V3 nine-kind visuals: consume only declared keys, no reparent, no N/A");
}

{
  const window = boot(null, tree);
  const text = window.document.querySelector(".ux-render-root").textContent;
  assert.equal(window.VvHtmlComponents.gate().reason, "no-block");
  assert.equal(text.includes("CANARY-BODY-TEXT"), false);
  console.log("ok V3 no-block still does not invent payload");
}

console.log("V3 ok");
