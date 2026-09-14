/* Core homepage stub. Pair/bind + app list. Overlay may replace /. */
(function () {
  "use strict";
  var sk = window.FrontSkeleton;
  if (!sk) return;
  sk.bindIfNeeded().then(function (env) {
    var el = document.getElementById("bindStatus");
    if (!el) return;
    if (!env || env.ok === false) {
      el.textContent = (env && env.reason) || "front_bind_refused";
      el.setAttribute("data-refusal-reason", el.textContent);
      return;
    }
    el.textContent = "bound " + (env.actorCid || "");
  });
})();
