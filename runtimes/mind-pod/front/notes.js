(function () {
  "use strict";
  var list = document.getElementById("list");
  var err = document.getElementById("err");
  function showErr(reason) {
    err.hidden = false;
    err.textContent = reason || "unknown";
  }
  function envelope(json) {
    if (!json || typeof json !== "object") return { ok: false, reason: "empty" };
    if (json.ok === false) return json;
    var result = json.result !== undefined ? json.result : json;
    if (Array.isArray(result)) return { ok: json.ok !== false, "@graph": result };
    return Object.assign({ ok: json.ok !== false }, result);
  }
  function refresh() {
    return fetch("/notes/list").then(function (r) { return r.json(); }).then(envelope).then(function (env) {
      if (env.ok === false) { showErr(env.reason); return; }
      var rows = env["@graph"] || [];
      list.textContent = "";
      if (!rows.length) {
        list.innerHTML = "<p class='sub'>No notes yet.</p>";
        return;
      }
      rows.forEach(function (n) {
        var d = document.createElement("div");
        d.className = "card";
        d.innerHTML = "<strong></strong><div></div><div class='sub'></div>";
        d.querySelector("strong").textContent = n.title || "";
        d.querySelector("div").textContent = n.body || "";
        d.querySelector(".sub").textContent = n["@id"] || "";
        list.appendChild(d);
      });
    });
  }
  document.getElementById("noteForm").addEventListener("submit", function (e) {
    e.preventDefault();
    var fd = new FormData(e.target);
    fetch("/notes", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        operationId: "op-note-" + Date.now(),
        title: fd.get("title"),
        body: fd.get("body")
      })
    }).then(function (r) { return r.json(); }).then(envelope).then(function (env) {
      if (env.ok === false) showErr(env.reason);
      e.target.reset();
      return refresh();
    });
  });
  refresh();
})();
