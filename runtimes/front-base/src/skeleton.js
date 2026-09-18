/* editor.js skeleton — closed parts. Overlays must not reimplement
 * envelope / bindIfNeeded / showSurface. Stage overrides call scheduleSave.
 * ghis-19@1 date is date_kind_missing; never compile date to text.
 */
(function (g) {
  "use strict";

  var DEBOUNCE_MS = 2000;

  function uid() {
    return "o_" + Math.random().toString(36).slice(2, 10);
  }

  function opId(kind) {
    return "op-" + kind + "-" + Date.now() + "-" + Math.random().toString(36).slice(2, 8);
  }

  function envelope(json) {
    if (!json || typeof json !== "object") return { ok: false, reason: "empty" };
    if (json.ok === false) return json;
    var result = json.result !== undefined ? json.result : json;
    if (Array.isArray(result)) return { ok: json.ok !== false, "@graph": result };
    return Object.assign({ ok: json.ok !== false }, result);
  }

  function namedBoards(env) {
    var list = [];
    if (env && Array.isArray(env["@graph"])) list = env["@graph"];
    else if (env && env.result && Array.isArray(env.result["@graph"])) list = env.result["@graph"];
    else if (env && Array.isArray(env.result)) list = env.result;
    return list.filter(function (p) {
      return p && typeof p === "object" && !Array.isArray(p) && p.id != null && String(p.id) !== "";
    }).map(function (p) {
      return {
        id: String(p.id),
        title: (p.title && String(p.title).trim()) || "Untitled",
        blobDigest: p.blobDigest || p.blob_digest || ""
      };
    });
  }

  function actorCid() {
    try { return sessionStorage.getItem("actorCid") || ""; } catch (e) { return ""; }
  }

  function rpc(method, url, body) {
    var headers = { "Content-Type": "application/json" };
    try {
      var token = sessionStorage.getItem("frontToken");
      if (token) headers["X-Front-Token"] = token;
    } catch (e) { /* private mode */ }
    var opts = { method: method, headers: headers };
    if (body) opts.body = JSON.stringify(body);
    return fetch(url, opts).then(function (r) { return r.json(); }).then(envelope);
  }

  function taskSlotEl() {
    return document.getElementById("taskSlot");
  }

  function showReason(reason) {
    var slot = taskSlotEl();
    if (!slot) return;
    slot.textContent = "";
    var p = document.createElement("p");
    p.setAttribute("data-refusal-reason", reason || "unknown");
    p.setAttribute("role", "alert");
    p.textContent = reason || "unknown";
    slot.appendChild(p);
  }

  var currentSurface = null;

  function putError(reason) {
    var why = reason || "unknown";
    return rpc("POST", "/canvas/ui/surface", {
      operationId: opId("ui"),
      taskKind: "task.error",
      title: why,
      stepKind: "error",
      pageCid: "journey:library"
    }).then(function (env) {
      if (!env || env.ok === false) {
        showReason(why);
        return env;
      }
      return showSurface(env, why);
    });
  }

  function putEmpty(titleText) {
    return rpc("POST", "/canvas/ui/surface", {
      operationId: opId("ui"),
      taskKind: "task.empty",
      title: titleText || "No rows",
      stepKind: "empty",
      pageCid: "journey:library"
    }).then(function (env) { return showSurface(env); });
  }

  function bindIfNeeded() {
    var token = document.body.getAttribute("data-front-token") || "";
    if (!token) {
      putError("front_bind_refused");
      return Promise.resolve({ ok: false, reason: "front_bind_refused" });
    }
    try { sessionStorage.setItem("frontToken", token); } catch (e) { /* private mode */ }
    return rpc("POST", "/canvas/front/bind", {
      operationId: opId("bind"),
      token: token
    }).then(function (env) {
      if (env && env.ok === false) {
        putError(env.reason || "front.bind refused");
        return env;
      }
      if (env && env.actorCid) {
        try { sessionStorage.setItem("actorCid", env.actorCid); } catch (e2) { /* ignore */ }
      }
      return env;
    });
  }

  function journalPath(path, verb, payload, alreadyApplied) {
    var body = {
      operationId: opId("front"),
      path: path,
      verb: verb
    };
    if (payload !== undefined) body.payload = payload;
    if (alreadyApplied) body.applied = true;
    var digest = g.FrontSkeleton && g.FrontSkeleton.lastDigest;
    if (digest) body.blobDigest = digest;
    return rpc("POST", "/canvas/front/path", body).then(function (env) {
      if (env && env.blobDigest && g.FrontSkeleton) {
        g.FrontSkeleton.lastDigest = env.blobDigest;
      }
      return env;
    });
  }

  function bindCatalogActions(surface) {
    currentSurface = surface;
    var slot = taskSlotEl();
    if (!slot) return;
    slot.onclick = function (e) {
      var el = e.target.closest("[data-ux-component-kind='ActionControl'], button");
      if (!el || !slot.contains(el) || !currentSurface) return;
      var action = (el.getAttribute("data-action") || "").toLowerCase();
      var label = (el.textContent || "").toLowerCase().trim();
      if (!action) {
        if (label.indexOf("submit") >= 0) action = "submit";
        else if (label.indexOf("accept") >= 0) action = "accept";
        else if (label.indexOf("reject") >= 0) action = "reject";
        else if (label.indexOf("acknowledge") >= 0) action = "acknowledge";
        else if (label.indexOf("dismiss") >= 0) action = "dismiss";
      }
      if (action === "submit-decision") action = "submit";
      if (!action) return;
      var body = {
        operationId: opId("ui-action"),
        surfaceCid: currentSurface.cid,
        action: action
      };
      if (currentSurface.jobId) body.jobId = currentSurface.jobId;
      rpc("POST", "/canvas/ui/action", body).then(function (env) {
        if (env && env.ok === false) putError(env.reason);
      });
    };
  }

  function showSurface(env, fallbackReason) {
    if (!env || env.ok === false) {
      return putError((env && env.reason) || fallbackReason || "unknown");
    }
    var cid = env.cid || env.aciaCid;
    if (!cid) {
      showReason(fallbackReason || "lineage_unresolved");
      return Promise.resolve(env);
    }
    currentSurface = { cid: cid, jobId: env.jobId };
    return rpc("GET", "/canvas/ui/surface?aciaCid=" + encodeURIComponent(cid) + "&as=html").then(function (htmlEnv) {
      var slot = taskSlotEl();
      if (!htmlEnv || htmlEnv.ok === false) {
        showReason((htmlEnv && htmlEnv.reason) || fallbackReason || "unknown");
        return htmlEnv;
      }
      if (slot) {
        slot.innerHTML = htmlEnv.html || "";
        if (g.FrontCatalog && typeof g.FrontCatalog.enhance === "function") {
          g.FrontCatalog.enhance(slot);
        }
      }
      if (fallbackReason && slot && slot.textContent.indexOf(fallbackReason) < 0) {
        var p = document.createElement("p");
        p.setAttribute("data-refusal-reason", fallbackReason);
        p.textContent = fallbackReason;
        slot.appendChild(p);
      }
      bindCatalogActions(currentSurface);
      return rpc("GET", "/canvas/ui/surface?aciaCid=" + encodeURIComponent(cid) + "&as=a2ui").then(function (a2) {
        if (!a2 || a2.ok === false) return putError(a2 && a2.reason);
        var doc = a2.a2ui || a2;
        if (doc.version && doc.version !== "v0.9.1") return putError("a2ui_version");
        return env;
      });
    });
  }

  g.FrontSkeleton = {
    DEBOUNCE_MS: DEBOUNCE_MS,
    lastDigest: null,
    uid: uid,
    opId: opId,
    envelope: envelope,
    namedBoards: namedBoards,
    actorCid: actorCid,
    rpc: rpc,
    bindIfNeeded: bindIfNeeded,
    journalPath: journalPath,
    showReason: showReason,
    putError: putError,
    putEmpty: putEmpty,
    showSurface: showSurface,
    taskSlotEl: taskSlotEl
  };
})(typeof globalThis !== "undefined" ? globalThis : window);
