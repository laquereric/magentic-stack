/* Core homepage. Pair/bind required. App list hidden until bound. */
(function () {
  "use strict";
  var sk = window.FrontSkeleton;
  var status = document.getElementById("bindStatus");
  var apps = document.getElementById("apps");
  if (!sk) {
    if (status) {
      status.textContent = "front_bind_refused";
      status.setAttribute("data-refusal-reason", "front_bind_refused");
    }
    return;
  }
  sk.bindIfNeeded().then(function (env) {
    if (!status) return;
    if (!env || env.ok === false) {
      status.textContent = (env && env.reason) || "front_bind_refused";
      status.setAttribute("data-refusal-reason", status.textContent);
      if (apps) apps.hidden = true;
      return;
    }
    status.textContent = "bound " + (env.actorCid || "");
    if (apps) apps.hidden = false;
  });
})();
