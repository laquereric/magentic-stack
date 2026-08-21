#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const js = readFileSync(join(root, "dist/vv-html-components.js"), "utf8");
const { JSDOM } = createRequire(import.meta.url)(join(here, "node_modules/jsdom"));

function boot(pkg, bodyHtml) {
  const live = new JSDOM("<!doctype html><html><head></head><body></body></html>", {
    runScripts: "dangerously",
    url: "https://example.test/v4"
  });
  const s = live.window.document.createElement("script");
  s.setAttribute("type", "application/ld+json");
  s.setAttribute("data-ux-acia-document", "");
  s.textContent = JSON.stringify(pkg);
  live.window.document.head.appendChild(s);
  live.window.document.body.innerHTML = bodyHtml;
  live.window.eval(js);
  if (live.window.document.readyState === "loading") {
    live.window.document.dispatchEvent(new live.window.Event("DOMContentLoaded", { bubbles: true }));
  }
  return live.window;
}

const digest = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

function node(id, kind, extra = "") {
  return `<div data-ux-node-cid="cid:node:${id}" data-ux-node-id="${id}"
    data-ux-component-kind="${kind}" data-ux-acia-digest="${digest}"
    data-ux-token-digest="sha256:bbb" data-ux-content-role="context" aria-label="${kind}">
    <span data-ux-label>${kind}</span>${extra}</div>`;
}

{
  const pkg = {
    correlation: "corr-v4",
    aciaDigest: digest,
    document: {
      rootNode: {
        nodeId: "shell-001",
        componentKind: "PageShell",
        props: { valueJson: { title: "Review" } },
        children: [
          {
            nodeId: "rn-001",
            componentKind: "RefusalNotice",
            props: {
              valueJson: {
                operation: "ux.interaction.record",
                reason: "UX_EFFECT_AFFORDANCE_DENIED",
                failedCriteria: ["authorization.scope"],
                evidenceRefs: ["https://ex/p6/ev"],
                remediation: "CANARY-REMEDIATION-TEXT",
                overridePolicy: "none",
                heading: "Effect refused",
                unused: "CANARY-UNUSED-KEY"
              }
            }
          },
          {
            nodeId: "rb-001",
            componentKind: "ReferentBridge",
            props: {
              valueJson: {
                sourceConcept: "https://ex/c",
                sourceDefinitionRevision: "https://ex/r",
                targetExpression: "cooling-access-site",
                mappingArtifact: "https://ex/map",
                mappingProof: "https://ex/proof",
                sourceToTargetScope: "https://ex/scope/from-to"
              }
            }
          },
          {
            nodeId: "rb-bad",
            componentKind: "ReferentBridge",
            props: { valueJson: { sourceConcept: "https://ex/c", targetExpression: "x" } }
          }
        ]
      }
    }
  };
  const html = `<div class="ux-render-root" data-ux-correlation="corr-v4" data-ux-acia-digest="${digest}">
    ${node("shell-001", "PageShell", node("rn-001", "RefusalNotice") + node("rb-001", "ReferentBridge") + node("rb-bad", "ReferentBridge"))}
  </div>`;
  const window = boot(pkg, html);
  const text = window.document.querySelector(".ux-render-root").textContent;
  assert.equal(window.VvHtmlComponents.gate().ok, true);
  assert.ok(text.includes("CANARY-REMEDIATION-TEXT"));
  assert.ok(text.includes("No override is available."));
  assert.equal(window.document.querySelector('[data-ux-node-id="rn-001"] button'), null);
  assert.equal(text.includes("CANARY-UNUSED-KEY"), false);
  assert.ok(text.includes("https://ex/scope/from-to"));
  const incomplete = window.document.querySelector('[data-ux-node-id="rb-bad"]');
  const complete = window.document.querySelector('[data-ux-node-id="rb-001"]');
  assert.ok(incomplete.textContent.includes("retention claim incomplete"));
  assert.equal(incomplete.textContent.includes("retained through mapping"), false);
  assert.equal(complete.textContent.includes("retention claim incomplete"), false);
  assert.ok(complete.textContent.includes("retained through mapping"));
  assert.ok(complete.querySelector(".vv-rb-source"));
  assert.ok(complete.querySelector(".vv-rb-target"));
  assert.ok(complete.querySelector(".vv-rb-basis"));
  assert.ok(complete.querySelector(".vv-rb-scope"));
  assert.equal(complete.querySelector("a"), null, "IRIs are text, not links");
  console.log("ok V4 RefusalNotice P9.10 + ReferentBridge five-region claim / incomplete qualifier");
}

console.log("V4 ok");
