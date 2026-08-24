/* ux-host-layout.js — Host Layout Projection for Profile 9 ACIA trees.
 *
 * NOT vv-html-components. NOT the renderer. Reads layoutKind / layoutArity /
 * responsiveSignature from embedded JSON-LD only. Joins by existing
 * data-ux-acia-digest + data-ux-node-id. Never reparents, reorders, or
 * mutates data-ux-*. Fail closed to readable flow.
 */
(function (global) {
  "use strict";

  var STYLE_ID = "ux-host-layout-rules";
  var COMPACT = "48rem";
  var RECIPES = {
    "p9.r1.grid.board-5": { family: "grid", tracksWide: 5, compact: "stack", childCount: 5 },
    "p9.r1.grid.board-3": { family: "grid", tracksWide: 3, compact: "stack", childCount: 3 },
    "p9.r1.grid.generic": { family: "grid", tracksWide: "auto", compact: "stack" },
    "p9.r1.default": { family: "flow", compact: "flow" },
    "default": { family: "flow", compact: "flow" }
  };

  function arityOk(arity, count) {
    if (arity === "one") return count === 1;
    if (arity === "two") return count === 2;
    if (arity === "three") return count === 3;
    if (arity === "many") return count >= 4;
    return false;
  }

  function decide(kind, arity, signature, count) {
    if (!arityOk(arity, count)) return { apply: false, reason: "arity" };
    var sig = signature || "default";
    if (sig === "") sig = "default";
    var recipe = RECIPES[sig];
    if (!recipe) return { apply: false, reason: "unknown-signature" };
    if (recipe.family === "flow" || sig === "default") return { apply: false, reason: "safe-generic" };
    if (recipe.family !== kind) return { apply: false, reason: "family-mismatch" };
    if (recipe.childCount && recipe.childCount !== count) return { apply: false, reason: "child-count" };
    return { apply: true, recipe: recipe, signature: sig, childCount: count };
  }

  function participatingChildren(el) {
    var out = [];
    if (!el) return out;
    var kids = el.children;
    var i;
    for (i = 0; i < kids.length; i++) {
      if (kids[i].getAttribute && kids[i].getAttribute("data-ux-node-id")) out.push(kids[i]);
    }
    return out;
  }

  function aciaChildren(node) {
    var kids = (node && node.children) || [];
    var out = [];
    var i;
    for (i = 0; i < kids.length; i++) {
      if (kids[i] && kids[i].nodeId) out.push(kids[i]);
    }
    return out;
  }

  function topologyMatch(aciaKids, domKids) {
    if (aciaKids.length !== domKids.length) return false;
    var i;
    for (i = 0; i < aciaKids.length; i++) {
      if (aciaKids[i].nodeId !== (domKids[i].getAttribute("data-ux-node-id") || "")) return false;
    }
    return true;
  }

  function findEl(root, digest, nodeId) {
    if (!root || !root.querySelector) return null;
    var sel = '[data-ux-acia-digest="' + cssEscape(digest) + '"][data-ux-node-id="' + cssEscape(nodeId) + '"]';
    if (root.getAttribute && root.getAttribute("data-ux-node-id") === nodeId &&
        root.getAttribute("data-ux-acia-digest") === digest) {
      return root;
    }
    return root.querySelector(sel);
  }

  function cssEscape(s) {
    return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  }

  function cssFor(digest, nodeId, recipe) {
    var key = '[data-ux-acia-digest="' + cssEscape(digest) + '"][data-ux-node-id="' + cssEscape(nodeId) + '"]';
    if (!recipe || recipe.family !== "grid") return "";
    var tracks = recipe.tracksWide === "auto" ? "repeat(auto-fit, minmax(12rem, 1fr))" :
      "repeat(" + recipe.tracksWide + ", minmax(12rem, 1fr))";
    var wide = key + "{display:grid;grid-template-columns:" + tracks + ";gap:1rem;}";
    wide += key + ">[data-ux-label]{grid-column:1/-1;}";
    var compact = "@media (max-width:" + COMPACT + "){" + key + "{display:block;grid-template-columns:none;}";
    compact += key + ">[data-ux-label]{grid-column:auto;}}";
    return wide + compact;
  }

  function walk(node, ctx) {
    if (!node || typeof node !== "object") return;
    var nodeId = node.nodeId || "";
    var slt = node.slt || {};
    if (nodeId) {
      var el = findEl(ctx.rootEl, ctx.digest, nodeId);
      if (el && el.getAttribute("data-ux-node-cid") &&
          el.getAttribute("data-ux-acia-digest") === ctx.digest) {
        var aciaKids = aciaChildren(node);
        var domKids = participatingChildren(el);
        if (topologyMatch(aciaKids, domKids)) {
          var decision = decide(
            slt.layoutKind || "stack",
            slt.layoutArity || "",
            slt.responsiveSignature || "default",
            domKids.length
          );
          if (decision.apply) {
            ctx.css.push(cssFor(ctx.digest, nodeId, decision.recipe));
            ctx.applied.push(nodeId);
          }
        }
      }
    }
    var kids = node.children || [];
    var i;
    for (i = 0; i < kids.length; i++) walk(kids[i], ctx);
  }

  function apply(doc) {
    doc = doc || (typeof document !== "undefined" ? document : null);
    if (!doc) return { applied: [], reason: "no-document" };
    var rootEl = doc.querySelector(".ux-render-root");
    var script = doc.querySelector("script[data-ux-acia-document]");
    if (!rootEl || !script) return { applied: [], reason: "no-document" };
    var pkg;
    try {
      pkg = JSON.parse(script.textContent || "");
    } catch (_e) {
      return { applied: [], reason: "malformed" };
    }
    if (!pkg || typeof pkg !== "object") return { applied: [], reason: "malformed" };
    var acia = pkg.document || pkg.aciaDocument;
    if (!acia || typeof acia !== "object") return { applied: [], reason: "malformed" };
    var tree = acia.rootNode || acia.root;
    if (!tree || typeof tree !== "object") return { applied: [], reason: "malformed" };
    var pageDigest = rootEl.getAttribute("data-ux-acia-digest") || "";
    var pkgDigest = pkg.aciaDigest || "";
    if (!pageDigest || !pkgDigest || pageDigest !== pkgDigest) {
      return { applied: [], reason: "mismatch" };
    }
    var ctx = { rootEl: rootEl, digest: pageDigest, css: [], applied: [] };
    walk(tree, ctx);
    var style = doc.getElementById(STYLE_ID);
    if (!style) {
      style = doc.createElement("style");
      style.id = STYLE_ID;
      (doc.head || doc.documentElement).appendChild(style);
    }
    style.textContent = ctx.css.join("");
    return { applied: ctx.applied, reason: ctx.applied.length ? "ok" : "none" };
  }

  var api = { apply: apply, decide: decide, recipes: RECIPES };
  global.UxHostLayout = api;

  if (typeof document !== "undefined") {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", function () { apply(document); });
    }
  }
})(typeof window !== "undefined" ? window : typeof globalThis !== "undefined" ? globalThis : this);
