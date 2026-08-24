#!/usr/bin/env node
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import assert from "node:assert/strict";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const js = readFileSync(join(root, "dist/vv-html-components.js"), "utf8");
const { JSDOM } = createRequire(import.meta.url)(join(here, "node_modules/jsdom"));

function bootFromHtmlFile(path) {
  const html = readFileSync(path, "utf8");
  const inert = new JSDOM(html);
  const live = new JSDOM("<!doctype html><html><head></head><body></body></html>", {
    runScripts: "dangerously",
    url: "https://example.test/v5"
  });
  const srcBlock = inert.window.document.querySelector("script[data-ux-acia-document]");
  if (srcBlock) {
    const s = live.window.document.createElement("script");
    s.setAttribute("type", "application/ld+json");
    s.setAttribute("data-ux-acia-document", "");
    s.textContent = srcBlock.textContent;
    live.window.document.head.appendChild(s);
  }
  const srcRoot = inert.window.document.querySelector(".ux-render-root");
  if (srcRoot) live.window.document.body.innerHTML = srcRoot.outerHTML;
  live.window.eval(js);
  if (live.window.document.readyState === "loading") {
    live.window.document.dispatchEvent(new live.window.Event("DOMContentLoaded", { bubbles: true }));
  }
  return live.window;
}

const sb = join(root, "../app-oriented-translation/docs/storyboards/html");
const pages = [
  "01-a1-orientation-arrival.html",
  "07-b4-meaning-actability-receipt.html",
  "11-c4-translation-issued.html"
];

for (const page of pages) {
  const p = join(sb, page);
  assert.ok(existsSync(p), "missing storyboard " + page + " (read-only check)");
  const window = bootFromHtmlFile(p);
  const rootEl = window.document.querySelector(".ux-render-root");
  assert.ok(rootEl, page + " has render root");
  assert.ok(rootEl.querySelector("[data-ux-label]"), page + " stays readable");
  const gate = window.VvHtmlComponents.gate();
  console.log("storyboard", page, "gate", gate.reason, "ok", gate.ok);
}

{
  const digest = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  const kinds = [
    "PageShell", "PanelFrame", "SemanticText", "StatusBadge", "MetricStrip",
    "ContextBanner", "DrillDownCard", "DataList", "Timeline", "EvidencePanel",
    "DecisionForm", "ActionControl", "Disclosure", "FilterBar", "TabSet",
    "EmptyState", "RefusalNotice", "ScopeTrail", "ReferentBridge"
  ];
  const children = kinds.slice(1).map((k, i) => ({
    nodeId: "n-" + (i + 2).toString().padStart(3, "0"),
    componentKind: k,
    props: { valueJson: { heading: k, body: "present" } }
  }));
  children.find((c) => c.componentKind === "RefusalNotice").props.valueJson = {
    operation: "ux.interaction.record",
    reason: "UX_EFFECT_AFFORDANCE_DENIED",
    failedCriteria: ["authorization.scope"],
    evidenceRefs: ["https://ex/e"],
    remediation: "Retry.",
    overridePolicy: "none"
  };
  children.find((c) => c.componentKind === "ReferentBridge").props.valueJson = {
    sourceConcept: "https://ex/c",
    sourceDefinitionRevision: "https://ex/r",
    targetExpression: "t",
    mappingArtifact: "https://ex/m",
    mappingProof: "https://ex/p",
    sourceToTargetScope: "https://ex/s"
  };
  const pkg = {
    correlation: "corr-v5",
    aciaDigest: digest,
    document: {
      rootNode: {
        nodeId: "n-001",
        componentKind: "PageShell",
        props: { valueJson: { title: "All kinds", body: "CANARY-BODY-TEXT" } },
        children
      }
    }
  };
  const inner = kinds.map((k, i) => {
    const id = "n-" + (i + 1).toString().padStart(3, "0");
    return `<div data-ux-node-id="${id}" data-ux-component-kind="${k}" data-ux-node-cid="cid:n${i}"
      data-ux-acia-digest="${digest}" data-ux-token-digest="sha256:x" data-ux-content-role="context" aria-label="${k}">
      <span data-ux-label>${k}</span></div>`;
  }).join("");
  const live = new JSDOM("<!doctype html><html><head></head><body></body></html>", {
    runScripts: "dangerously",
    url: "https://example.test/v5-19"
  });
  const s = live.window.document.createElement("script");
  s.setAttribute("type", "application/ld+json");
  s.setAttribute("data-ux-acia-document", "");
  s.textContent = JSON.stringify(pkg);
  live.window.document.head.appendChild(s);
  live.window.document.body.innerHTML =
    `<div class="ux-render-root" data-ux-correlation="corr-v5" data-ux-acia-digest="${digest}">${inner}</div>`;
  live.window.eval(js);
  const painted = live.window.document.querySelectorAll("[data-vv-kind]");
  console.log("nineteen-kind fixture painted", painted.length);
  assert.equal(painted.length, 19);
  assert.ok(live.window.document.body.textContent.includes("CANARY-BODY-TEXT"));
}

console.log("V5 ok");
