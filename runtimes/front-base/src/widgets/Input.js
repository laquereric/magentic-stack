/* ghis catalog module. Light-DOM. Not a custom element. */
(function (g) {
  "use strict";
  var KIND = "Input";
  g.FrontCatalog = g.FrontCatalog || { kinds: [], enhancers: {} };
  if (g.FrontCatalog.kinds.indexOf(KIND) < 0) g.FrontCatalog.kinds.push(KIND);
  g.FrontCatalog.enhancers[KIND] = function (el) {
    if (!el) return;
    el.setAttribute("data-vv-kind", KIND);
  };
})(typeof globalThis !== "undefined" ? globalThis : window);
