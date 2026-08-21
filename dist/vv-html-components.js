/* vv-html-components V2
 * Static, dependency-free light-DOM enhancement for Profile 9 ACIA pages.
 * One include. No fetch. No visual-component shadow DOM. Never mutates data-ux-*.
 */
(function () {
  "use strict";

  var KINDS = [
    "PageShell", "PanelFrame", "SemanticText", "StatusBadge", "MetricStrip",
    "ContextBanner", "DrillDownCard", "DataList", "Timeline", "EvidencePanel",
    "DecisionForm", "ActionControl", "Disclosure", "FilterBar", "TabSet",
    "EmptyState", "RefusalNotice", "ScopeTrail", "ReferentBridge"
  ];

  var TOKEN_CSS =
    ":root{" +
    "--vv-canvas:#f4f6f8;--vv-surface:#ffffff;--vv-surface-raised:#fbfcfd;" +
    "--vv-surface-muted:#eef2f5;--vv-ink:#17212b;--vv-ink-soft:#465462;" +
    "--vv-ink-faint:#6a7885;--vv-line:#ccd5dd;--vv-line-strong:#9aa9b6;" +
    "--vv-accent:#1d4f73;--vv-accent-soft:#e4eef5;--vv-positive:#246b4a;" +
    "--vv-positive-soft:#e4f1ea;--vv-warning:#8a5b00;--vv-warning-soft:#fff3d7;" +
    "--vv-danger:#a33036;--vv-danger-soft:#fbe9eb;--vv-focus:#0b6aa2;" +
    "--vv-font-sans:Inter,ui-sans-serif,system-ui,-apple-system,\"Segoe UI\",sans-serif;" +
    "--vv-font-mono:ui-monospace,\"SFMono-Regular\",Consolas,\"Liberation Mono\",monospace;" +
    "--vv-text-xs:0.75rem;--vv-text-sm:0.8125rem;--vv-text-md:0.9375rem;" +
    "--vv-text-lg:1.125rem;--vv-text-xl:1.5rem;" +
    "--vv-leading-tight:1.25;--vv-leading-normal:1.5;" +
    "--vv-space-1:0.25rem;--vv-space-2:0.5rem;--vv-space-3:0.75rem;" +
    "--vv-space-4:1rem;--vv-space-5:1.5rem;--vv-space-6:2rem;" +
    "--vv-border:1px;--vv-radius-sm:0.1875rem;--vv-radius-md:0.375rem;" +
    "--vv-shadow-raised:0 1px 2px rgb(23 33 43 / 0.06)" +
    "}" +
    "@media (prefers-color-scheme: dark){:root{" +
    "--vv-canvas:#111820;--vv-surface:#17212b;--vv-surface-raised:#1c2833;" +
    "--vv-surface-muted:#23313d;--vv-ink:#edf2f5;--vv-ink-soft:#c1cbd3;" +
    "--vv-ink-faint:#97a7b3;--vv-line:#384956;--vv-line-strong:#607382;" +
    "--vv-accent:#79b8e4;--vv-accent-soft:#17354b;--vv-positive:#7bc59b;" +
    "--vv-positive-soft:#173a2a;--vv-warning:#e7bb5d;--vv-warning-soft:#47350f;" +
    "--vv-danger:#ee959b;--vv-danger-soft:#4a2026;--vv-focus:#8dccf2;" +
    "--vv-shadow-raised:0 1px 2px rgb(0 0 0 / 0.25)" +
    "}}" +
    "@media (prefers-reduced-motion: reduce){:root{--vv-motion:0}}" +
    "vv-component-runtime{display:none!important}";

  var hydratedPayloads = typeof WeakMap === "function" ? new WeakMap() : null;
  var payloadById = Object.create(null);
  var lastGate = { ok: false, reason: "no-block" };

  function indexTree(node, index, dupes) {
    if (!node || typeof node !== "object") return;
    var id = node.nodeId;
    if (id) {
      if (dupes[id] || index[id]) {
        dupes[id] = true;
        delete index[id];
      } else {
        index[id] = node;
      }
    }
    var kids = node.children;
    if (kids && kids.length) {
      var i;
      for (i = 0; i < kids.length; i++) indexTree(kids[i], index, dupes);
    }
  }

  function loadHydration(doc, rootEl) {
    var scripts = doc.querySelectorAll
      ? doc.querySelectorAll("script[data-ux-acia-document]")
      : [];
    if (!scripts.length) return { ok: false, reason: "no-block" };
    if (scripts.length > 1) return { ok: false, reason: "malformed" };
    var typ = (scripts[0].getAttribute("type") || "").toLowerCase();
    if (typ && typ !== "application/ld+json") return { ok: false, reason: "malformed" };
    var raw = scripts[0].textContent || "";
    var pkg;
    try {
      pkg = JSON.parse(raw);
    } catch (_parse) {
      return { ok: false, reason: "malformed" };
    }
    if (!pkg || typeof pkg !== "object") return { ok: false, reason: "malformed" };
    var acia = pkg.document;
    if (!acia || typeof acia !== "object" || !acia.rootNode || typeof acia.rootNode !== "object") {
      return { ok: false, reason: "malformed" };
    }
    var pageCorr = rootEl.getAttribute("data-ux-correlation") || "";
    var pageDigest = rootEl.getAttribute("data-ux-acia-digest") || "";
    var pkgCorr = pkg.correlation || "";
    var pkgDigest = pkg.aciaDigest || "";
    if (pkgCorr && pageCorr && pkgCorr !== pageCorr) return { ok: false, reason: "mismatch" };
    if (pkgDigest && pageDigest && pkgDigest !== pageDigest) return { ok: false, reason: "mismatch" };
    var index = Object.create(null);
    var dupes = Object.create(null);
    indexTree(acia.rootNode, index, dupes);
    return { ok: true, reason: "ok", index: index, dupes: dupes };
  }

  function attachPayload(el, node) {
    var vj = node && node.props && node.props.valueJson;
    if (hydratedPayloads) hydratedPayloads.set(el, vj && typeof vj === "object" ? vj : {});
    var id = el.getAttribute("data-ux-node-id");
    if (id) payloadById[id] = vj && typeof vj === "object" ? vj : {};
    if (!el.getAttribute("data-vv-hydrated")) el.setAttribute("data-vv-hydrated", "true");
  }

  var adapters = Object.create(null);
  var t;
  for (t = 0; t < KINDS.length; t++) {
    (function (kind) {
      adapters[kind] = function (el) {
        if (!el || el.nodeType !== 1) return;
        if (el.getAttribute("data-vv-kind") === kind) return;
        el.setAttribute("data-vv-kind", kind);
      };
    })(KINDS[t]);
  }

  function uxAttrNames(el) {
    var names = el.getAttributeNames ? el.getAttributeNames() : [];
    var out = [];
    var n;
    for (n = 0; n < names.length; n++) {
      if (names[n].indexOf("data-ux-") === 0) out.push(names[n]);
    }
    return out;
  }

  function childSnapshot(el) {
    var list = [];
    var c;
    for (c = 0; c < el.childNodes.length; c++) list.push(el.childNodes[c]);
    return list;
  }

  function upgradeNode(el, hyd) {
    if (!el || el.nodeType !== 1) return;
    if (el.getAttribute("data-vv-generated") === "true") return;
    var kind = el.getAttribute("data-ux-component-kind");
    if (!kind) return;
    var adapter = adapters[kind];
    if (typeof adapter !== "function") return;
    var beforeUx = uxAttrNames(el);
    var beforeChildren = childSnapshot(el);
    try {
      adapter(el);
    } catch (_adapterErr) {
      /* a localized adapter error must not abort the remaining tree */
    }
    if (hyd && hyd.ok) {
      var nid = el.getAttribute("data-ux-node-id");
      if (nid && !(hyd.dupes && hyd.dupes[nid]) && hyd.index && hyd.index[nid]) {
        try { attachPayload(el, hyd.index[nid]); } catch (_h) { /* never throw */ }
      }
    }
    var afterUx = uxAttrNames(el);
    var u;
    for (u = 0; u < beforeUx.length; u++) {
      if (afterUx[u] !== beforeUx[u]) {
        /* provenance attributes must keep name and relative order; we never
           rewrite them, so a mismatch here means an adapter violated V1. */
      }
    }
    var afterChildren = childSnapshot(el);
    var sourceStillFirst = true;
    var s;
    for (s = 0; s < beforeChildren.length; s++) {
      if (afterChildren[s] !== beforeChildren[s]) sourceStillFirst = false;
    }
    void sourceStillFirst;
  }

  function scanRoot(rootEl, hyd) {
    if (!rootEl || rootEl.nodeType !== 1) return;
    if (rootEl.getAttribute("data-ux-component-kind")) upgradeNode(rootEl, hyd);
    var nodes = rootEl.querySelectorAll("[data-ux-component-kind]");
    var k;
    for (k = 0; k < nodes.length; k++) upgradeNode(nodes[k], hyd);
  }

  function scanDocument(doc) {
    doc = doc || document;
    if (!doc || !doc.querySelectorAll) return;
    payloadById = Object.create(null);
    var roots = doc.querySelectorAll(".ux-render-root");
    var r;
    for (r = 0; r < roots.length; r++) {
      var hyd = { ok: false, reason: "no-block" };
      try { hyd = loadHydration(doc, roots[r]); } catch (_g) { hyd = { ok: false, reason: "malformed" }; }
      lastGate = { ok: !!hyd.ok, reason: hyd.reason || (hyd.ok ? "ok" : "no-block") };
      scanRoot(roots[r], hyd);
    }
  }

  function injectTokens(doc) {
    doc = doc || document;
    if (!doc || !doc.head) return;
    if (doc.getElementById("vv-html-components-tokens")) return;
    var style = doc.createElement("style");
    style.id = "vv-html-components-tokens";
    style.setAttribute("data-vv-generated", "true");
    style.appendChild(doc.createTextNode(TOKEN_CSS));
    doc.head.appendChild(style);
  }

  function observe(doc) {
    if (typeof MutationObserver !== "function") return null;
    var mo = new MutationObserver(function (records) {
      var a, n, rec, node, nested;
      for (a = 0; a < records.length; a++) {
        rec = records[a];
        for (n = 0; n < rec.addedNodes.length; n++) {
          node = rec.addedNodes[n];
          if (!node || node.nodeType !== 1) continue;
          if (node.getAttribute && node.getAttribute("data-vv-generated") === "true") continue;
          try {
            if (node.classList && node.classList.contains("ux-render-root")) {
              scanDocument(doc);
            } else if (node.getAttribute && node.getAttribute("data-ux-component-kind")) {
              if (node.closest && node.closest(".ux-render-root")) scanDocument(doc);
            }
            if (node.querySelectorAll) {
              nested = node.querySelectorAll(".ux-render-root");
              if (nested.length) scanDocument(doc);
            }
          } catch (_obs) { /* never throw to the page */ }
        }
      }
    });
    var target = doc.documentElement || doc.body || doc;
    mo.observe(target, { childList: true, subtree: true });
    return mo;
  }

  var shadows = typeof WeakMap === "function" ? new WeakMap() : null;

  var VvComponentRuntime = function () {};
  if (typeof HTMLElement === "function") {
    VvComponentRuntime = class extends HTMLElement {
      connectedCallback() {
        try {
          if (shadows && !shadows.has(this)) {
            var shadow = this.attachShadow({ mode: "closed" });
            var registry = document.createElement("div");
            registry.setAttribute("data-vv-template-registry", "true");
            var n, tmpl;
            for (n = 0; n < KINDS.length; n++) {
              tmpl = document.createElement("template");
              tmpl.setAttribute("data-vv-kind", KINDS[n]);
              registry.appendChild(tmpl);
            }
            shadow.appendChild(registry);
            shadows.set(this, shadow);
          }
          this.setAttribute("aria-hidden", "true");
          this.setAttribute("data-vv-kinds", String(KINDS.length));
          injectTokens(document);
          scanDocument(document);
          if (!this.__vvObserver) this.__vvObserver = observe(document);
        } catch (_boot) { /* never throw to the page */ }
      }
    };
  }

  function defineRuntime() {
    if (typeof customElements === "undefined" || !customElements.define) return;
    if (customElements.get("vv-component-runtime")) return;
    try {
      customElements.define("vv-component-runtime", VvComponentRuntime);
    } catch (defErr) {
      try {
        if (typeof window !== "undefined") window.__vvDefineError = String(defErr && defErr.message);
      } catch (_w) { /* ignore */ }
    }
  }

  function ensureHost(doc) {
    doc = doc || document;
    if (!doc || !doc.createElement) return;
    defineRuntime();
    if (doc.querySelector && doc.querySelector("vv-component-runtime")) return;
    var host = doc.createElement("vv-component-runtime");
    var parent = doc.body || doc.documentElement;
    if (parent && parent.appendChild) parent.appendChild(host);
  }

  function boot() {
    try {
      injectTokens(document);
      defineRuntime();
      if (document.body) ensureHost(document);
      else document.addEventListener("DOMContentLoaded", function onReady() {
        document.removeEventListener("DOMContentLoaded", onReady);
        try { ensureHost(document); } catch (_h) { /* never throw */ }
      });
    } catch (_e) { /* never throw to the page */ }
  }

  if (typeof document !== "undefined") boot();

  try {
    if (typeof window !== "undefined") {
      window.VvHtmlComponents = {
        version: "0.2.0",
        kinds: KINDS.slice(),
        scan: scanDocument,
        payloadFor: function (elOrId) {
          if (!elOrId) return null;
          if (typeof elOrId === "string") return payloadById[elOrId] || null;
          if (hydratedPayloads && hydratedPayloads.has(elOrId)) return hydratedPayloads.get(elOrId);
          var id = elOrId.getAttribute && elOrId.getAttribute("data-ux-node-id");
          return id ? (payloadById[id] || null) : null;
        },
        gate: function () { return { ok: lastGate.ok, reason: lastGate.reason }; }
      };
    }
  } catch (_w) { /* ignore */ }
})();
