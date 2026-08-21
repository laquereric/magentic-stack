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

  var VISUAL_CSS =
    ".ux-render-root{background:var(--vv-canvas);color:var(--vv-ink);font-family:var(--vv-font-sans);font-size:var(--vv-text-md);line-height:var(--vv-leading-normal)}" +
    ".ux-render-root [data-ux-label]{font-weight:600}" +
    "[data-vv-kind]{box-sizing:border-box}" +
    ".vv-payload{margin-top:var(--vv-space-2);font-size:var(--vv-text-sm);color:var(--vv-ink-soft)}" +
    ".vv-field{margin:var(--vv-space-1) 0}" +
    ".vv-k{display:block;font-size:var(--vv-text-xs);letter-spacing:.04em;text-transform:uppercase;color:var(--vv-ink-faint)}" +
    ".vv-v{display:block;color:var(--vv-ink)}" +
    ".vv-list .vv-li{display:block;font-family:var(--vv-font-mono);font-size:var(--vv-text-xs);word-break:break-all}" +
    ".vv-pageshell{max-width:64rem;margin:0 auto;padding:var(--vv-space-5) var(--vv-space-6);background:var(--vv-canvas)}" +
    ".vv-pageshell>[data-ux-label]{display:block;font-size:var(--vv-text-xl);line-height:var(--vv-leading-tight);color:var(--vv-ink);margin-bottom:var(--vv-space-3)}" +
    ".vv-pageshell>.vv-payload{border-top:var(--vv-border) solid var(--vv-line);padding-top:var(--vv-space-3);margin-bottom:var(--vv-space-4)}" +
    ".vv-panelframe{background:var(--vv-surface);border:var(--vv-border) solid var(--vv-line);border-radius:var(--vv-radius-md);padding:var(--vv-space-3) var(--vv-space-4);margin:var(--vv-space-3) 0;box-shadow:var(--vv-shadow-raised)}" +
    ".vv-panelframe.vv-state-emphasis,.vv-panelframe.vv-state-warning,.vv-panelframe.vv-state-danger{border-left:4px solid var(--vv-accent)}" +
    ".vv-panelframe.vv-state-warning{border-left-color:var(--vv-warning);background:var(--vv-warning-soft)}" +
    ".vv-panelframe.vv-state-danger{border-left-color:var(--vv-danger);background:var(--vv-danger-soft)}" +
    ".vv-semantictext>[data-ux-label]{display:block}" +
    ".vv-semantictext .vv-field-heading .vv-v{font-size:var(--vv-text-xs);text-transform:uppercase;letter-spacing:.04em;color:var(--vv-ink-faint)}" +
    ".vv-statusbadge{display:inline-block;border:var(--vv-border) solid var(--vv-line-strong);border-radius:var(--vv-radius-sm);padding:0.125rem var(--vv-space-2);font-size:var(--vv-text-xs);background:var(--vv-surface)}" +
    ".vv-statusbadge.vv-state-warning{border-color:var(--vv-warning);color:var(--vv-warning);background:var(--vv-warning-soft)}" +
    ".vv-statusbadge.vv-state-danger{border-color:var(--vv-danger);color:var(--vv-danger);background:var(--vv-danger-soft)}" +
    ".vv-metricstrip{display:flex;flex-wrap:wrap;gap:var(--vv-space-4);align-items:baseline;padding:var(--vv-space-2) 0}" +
    ".vv-metricstrip .vv-field-label .vv-v{color:var(--vv-ink-faint);font-size:var(--vv-text-xs)}" +
    ".vv-contextbanner{display:block;background:var(--vv-accent-soft);border:var(--vv-border) solid var(--vv-line);padding:var(--vv-space-3) var(--vv-space-4);margin:var(--vv-space-2) 0;color:var(--vv-ink)}" +
    ".vv-drilldowncard{border:var(--vv-border) solid var(--vv-line);border-radius:var(--vv-radius-sm);padding:var(--vv-space-3);margin:var(--vv-space-2) 0 0 var(--vv-space-3);background:var(--vv-surface-raised)}" +
    ".vv-datalist{list-style:none;padding-left:0;margin:var(--vv-space-2) 0}" +
    ".vv-datalist>:not([data-vv-generated]){display:block;border-bottom:var(--vv-border) solid var(--vv-line);padding:var(--vv-space-2) 0}" +
    ".vv-timeline{list-style:none;padding-left:var(--vv-space-4);margin:var(--vv-space-2) 0;border-left:2px solid var(--vv-line)}" +
    ".vv-timeline>:not([data-vv-generated]){position:relative;padding:var(--vv-space-2) 0 var(--vv-space-2) var(--vv-space-3)}" +
    ".vv-timeline>:not([data-vv-generated]):before{content:\"\";position:absolute;left:calc(-1 * var(--vv-space-4) - 3px);top:var(--vv-space-3);width:8px;height:8px;border-radius:50%;background:var(--vv-line-strong)}" +
    ".vv-state-quiet{opacity:0.88}" +
    ".vv-state-compact .vv-payload{font-size:var(--vv-text-xs)}" +
    "@media (forced-colors: active){.vv-panelframe,.vv-statusbadge,.vv-contextbanner,.vv-drilldowncard,.vv-refusalnotice,.vv-referentbridge{border:2px solid CanvasText}}" +
    ".vv-evidencepanel{border:var(--vv-border) solid var(--vv-line);border-radius:var(--vv-radius-md);padding:var(--vv-space-3);background:var(--vv-surface);margin:var(--vv-space-3) 0}" +
    ".vv-evidencepanel .vv-field-conclusion{border-top:2px solid var(--vv-line-strong);padding-top:var(--vv-space-2);margin-top:var(--vv-space-3)}" +
    ".vv-decisionform,.vv-disclosure,.vv-filterbar,.vv-tabset,.vv-emptystate{border:var(--vv-border) solid var(--vv-line);border-radius:var(--vv-radius-sm);padding:var(--vv-space-3);margin:var(--vv-space-2) 0;background:var(--vv-surface)}" +
    ".vv-actioncontrol{display:inline-block;margin:var(--vv-space-2) var(--vv-space-2) var(--vv-space-2) 0}" +
    "button.vv-actioncontrol{background:var(--vv-accent);color:var(--vv-surface);border:var(--vv-border) solid var(--vv-accent);border-radius:var(--vv-radius-sm);padding:var(--vv-space-2) var(--vv-space-3);font:inherit}" +
    ".vv-refusalnotice{border:var(--vv-border) solid var(--vv-danger);border-left:4px solid var(--vv-danger);background:var(--vv-danger-soft);padding:var(--vv-space-3) var(--vv-space-4);margin:var(--vv-space-3) 0;border-radius:var(--vv-radius-sm);color:var(--vv-ink)}" +
    ".vv-refusalnotice .vv-field-reason .vv-v,.vv-refusalnotice .vv-field-remediation .vv-v{color:var(--vv-ink);font-weight:500}" +
    ".vv-refusalnotice .vv-field-overridepolicy .vv-v{font-weight:600}" +
    ".vv-scopetrail{font-size:var(--vv-text-sm);padding:var(--vv-space-2) 0;color:var(--vv-ink-soft)}" +
    ".vv-scopetrail .vv-list .vv-li{display:inline;font-family:var(--vv-font-mono)}" +
    ".vv-scopetrail .vv-list .vv-li:not(:last-child):after{content:\" › \";color:var(--vv-ink-faint);font-family:var(--vv-font-sans)}" +
    ".vv-referentbridge{border:var(--vv-border) solid var(--vv-line-strong);border-radius:var(--vv-radius-md);padding:var(--vv-space-4);background:var(--vv-surface);margin:var(--vv-space-3) 0}" +
    ".vv-referentbridge .vv-readonly{background:var(--vv-surface-muted);padding:var(--vv-space-2);border:var(--vv-border) solid var(--vv-line)}" +
    ".vv-referentbridge .vv-incomplete{color:var(--vv-ink-soft);font-style:italic}";

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

  var STATES = "default compact expanded quiet emphasis warning danger disabled readonly".split(" ");
  var FIELD_LABELS = {
    heading: "Heading",
    body: "Body",
    references: "References",
    conclusion: "Conclusion",
    tone: "Tone",
    label: "Label",
    trigger: "Trigger",
    availability: "Availability",
    "ordered-scope": "Scope",
    operation: "Operation",
    reason: "Reason",
    failedCriteria: "Failed criteria",
    remediation: "Remediation",
    overridePolicy: "Override",
    evidenceRefs: "Evidence",
    action: "Action",
    heading: "Heading",
    trigger: "Trigger",
    reasonText: "Detail",
    sourceConcept: "Source concept",
    sourceDefinitionRevision: "Definition revision",
    targetExpression: "Target expression",
    mappingArtifact: "Mapping artifact",
    mappingProof: "Mapping proof",
    sourceToTargetScope: "Scope binding — read only"
  };
  var V3_CONTRACTS = {
    PageShell: ["heading", "body", "references", "conclusion"],
    PanelFrame: ["heading", "body", "tone", "conclusion"],
    SemanticText: ["heading", "body", "references"],
    StatusBadge: ["label", "tone", "body"],
    MetricStrip: ["label", "conclusion", "tone"],
    ContextBanner: ["heading", "body", "tone", "trigger", "availability"],
    DrillDownCard: ["heading", "body", "conclusion", "references", "tone"],
    DataList: ["heading", "body", "references", "ordered-scope"],
    Timeline: ["heading", "body", "trigger", "conclusion", "ordered-scope"]
  };
  var V4_CONTRACTS = {
    EvidencePanel: ["heading", "body", "references", "conclusion", "tone"],
    DecisionForm: ["heading", "body", "label", "action", "availability", "conclusion", "tone"],
    ActionControl: ["label", "action", "availability", "body", "tone"],
    Disclosure: ["heading", "body", "references", "conclusion", "availability"],
    FilterBar: ["label", "action", "availability", "body", "ordered-scope"],
    TabSet: ["label", "body", "availability", "ordered-scope"],
    EmptyState: ["heading", "body", "action", "availability", "ordered-scope", "tone"],
    RefusalNotice: ["operation", "reason", "failedCriteria", "remediation", "overridePolicy", "evidenceRefs", "heading", "trigger", "reasonText"],
    ScopeTrail: ["heading", "body", "ordered-scope", "references", "conclusion"],
    ReferentBridge: ["sourceConcept", "sourceDefinitionRevision", "targetExpression", "mappingArtifact", "mappingProof", "sourceToTargetScope", "conclusion", "references"]
  };
  var CONTRACTS = {};
  var ck;
  for (ck in V3_CONTRACTS) CONTRACTS[ck] = V3_CONTRACTS[ck];
  for (ck in V4_CONTRACTS) CONTRACTS[ck] = V4_CONTRACTS[ck];
  var REFERENT_REQUIRED = [
    "sourceConcept", "sourceDefinitionRevision", "targetExpression",
    "mappingArtifact", "mappingProof", "sourceToTargetScope"
  ];
  var LIST_KEYS = { references: 1, "ordered-scope": 1, failedCriteria: 1, evidenceRefs: 1 };

  function mk(tag, className, text) {
    var n = document.createElement(tag);
    n.setAttribute("data-vv-generated", "true");
    if (className) n.className = className;
    if (text != null) n.appendChild(document.createTextNode(text));
    return n;
  }

  function scalar(v) {
    if (v == null) return null;
    if (typeof v === "string") return v === "" ? null : v;
    if (typeof v === "number" || typeof v === "boolean") return String(v);
    return null;
  }

  function listVals(v) {
    if (typeof v === "string" && v !== "") return [v];
    if (!v || typeof v === "object" && !v.length) return null;
    if (!v.length) return null;
    var out = [];
    var i, s;
    for (i = 0; i < v.length; i++) {
      s = scalar(v[i]);
      if (s) out.push(s);
    }
    return out.length ? out : null;
  }

  function applyState(el, payload) {
    var st = "default";
    var tone;
    if (payload && STATES.indexOf(payload.presentationState) >= 0) st = payload.presentationState;
    else if (payload) {
      tone = scalar(payload.tone);
      if (tone) {
        tone = tone.toLowerCase();
        if (tone === "warning" || tone === "danger") st = tone;
      }
    }
    if (el.disabled) st = "disabled";
    else if (el.readOnly || el.getAttribute("aria-readonly") === "true") st = "readonly";
    if (el.classList) el.classList.add("vv-state-" + st);
  }

  function payloadTag(host) {
    var tag = (host.tagName || "").toUpperCase();
    if (tag === "UL" || tag === "OL") return "li";
    return "div";
  }

  function paintVisual(el, kind) {
    if (!el || el.getAttribute("data-vv-painted") === "true") return;
    if (el.classList) {
      el.classList.add("vv-kind");
      el.classList.add("vv-" + String(kind).toLowerCase());
    }
    var id = el.getAttribute("data-ux-node-id");
    var payload = id ? payloadById[id] : null;
    applyState(el, payload);
    var keys = CONTRACTS[kind];
    if (!keys || !payload) {
      el.setAttribute("data-vv-painted", "true");
      return;
    }
    var box = mk(payloadTag(el), "vv-payload");
    if (kind === "ReferentBridge") {
      var missing = [];
      var r;
      for (r = 0; r < REFERENT_REQUIRED.length; r++) {
        if (!scalar(payload[REFERENT_REQUIRED[r]])) missing.push(REFERENT_REQUIRED[r]);
      }
      if (missing.length) {
        box.appendChild(mk("div", "vv-field vv-incomplete", "retention claim incomplete"));
      }
    }
    var any = false;
    var i, key, raw, txt, items, row, list, j;
    for (i = 0; i < keys.length; i++) {
      key = keys[i];
      raw = payload[key];
      if (raw == null || raw === "") continue;
      if (LIST_KEYS[key]) {
        items = listVals(raw);
        if (!items) continue;
        row = mk("div", "vv-field vv-field-" + key);
        row.appendChild(mk("span", "vv-k", FIELD_LABELS[key] || key));
        list = mk("span", "vv-v vv-list");
        for (j = 0; j < items.length; j++) list.appendChild(mk("span", "vv-li", items[j]));
        row.appendChild(list);
        box.appendChild(row);
        any = true;
      } else {
        txt = scalar(raw);
        if (!txt) continue;
        if (kind === "RefusalNotice" && key === "overridePolicy" && txt === "none") {
          txt = "No override is available.";
        }
        row = mk("div", "vv-field vv-field-" + key);
        if (kind === "ReferentBridge" && key === "sourceToTargetScope") {
          row.className += " vv-readonly";
        }
        row.appendChild(mk("span", "vv-k", FIELD_LABELS[key] || key));
        row.appendChild(mk("span", "vv-v", txt));
        box.appendChild(row);
        any = true;
      }
    }
    if (kind === "ReferentBridge" && box.querySelector(".vv-incomplete")) any = true;
    if (any) el.appendChild(box);
    el.setAttribute("data-vv-painted", "true");
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
    try { paintVisual(el, kind); } catch (_p) { /* never throw */ }
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
    style.appendChild(doc.createTextNode(TOKEN_CSS + VISUAL_CSS));
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
        version: "0.4.0",
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
