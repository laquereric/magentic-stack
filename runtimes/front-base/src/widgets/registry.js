/* Closed ghis catalog. Unknown twentieth kind is left untouched.
 * DESIGN.md: do not turn semantic tags into custom elements.
 */
(function (g) {
  "use strict";
  var KINDS = [
    "PageShell", "PanelFrame", "SemanticText", "StatusBadge", "MetricStrip",
    "ContextBanner", "DrillDownCard", "DataList", "Timeline", "EvidencePanel",
    "DecisionForm", "ActionControl", "Disclosure", "FilterBar", "TabSet",
    "EmptyState", "RefusalNotice", "ScopeTrail", "ReferentBridge",
    "DateInput", "Input"
  ];
  g.FrontCatalog = g.FrontCatalog || { kinds: [], enhancers: {} };
  KINDS.forEach(function (k) {
    if (g.FrontCatalog.kinds.indexOf(k) < 0) g.FrontCatalog.kinds.push(k);
  });
  g.FrontCatalog.enhance = function (root) {
    var scope = root || document;
    var nodes = scope.querySelectorAll("[data-ux-component-kind]");
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var kind = el.getAttribute("data-ux-component-kind");
      var fn = g.FrontCatalog.enhancers[kind];
      if (fn) fn(el);
    }
  };
  g.FrontCatalog.includes = function (kind) {
    return KINDS.indexOf(kind) >= 0;
  };
  g.FrontCatalog.defineCustomElement = function () {
    throw new Error("ghis kinds are not custom elements");
  };
})(typeof globalThis !== "undefined" ? globalThis : window);
