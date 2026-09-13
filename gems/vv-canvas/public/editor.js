/* global fabric */
(function () {
  "use strict";

  var HOT = "sharedai-space:hot";
  var DEBOUNCE_MS = 2000;
  var canvas;
  var history = [];
  var historyIndex = -1;
  var restoring = false;
  var zoom = 1;
  var currentId = null;
  var lastDigest = null;
  var saveTimer = null;
  var boards = [];

  function uid() {
    return "o_" + Math.random().toString(36).slice(2, 10);
  }

  function opId(kind) {
    return "op-" + kind + "-" + Date.now() + "-" + Math.random().toString(36).slice(2, 8);
  }

  function envelope(json) {
    if (!json || typeof json !== "object") return { ok: false, reason: "empty" };
    if (json.ok === false) return json;
    var result = json.result || json;
    return Object.assign({ ok: json.ok !== false }, result);
  }

  function rpc(method, url, body) {
    var opts = { method: method, headers: { "Content-Type": "application/json" } };
    if (body) opts.body = JSON.stringify(body);
    return fetch(url, opts).then(function (r) { return r.json(); }).then(envelope);
  }

  function title() {
    return (document.getElementById("projectName").value || "Untitled").trim() || "Untitled";
  }

  function setStatus(text) {
    var el = document.getElementById("saveStatus");
    if (el) el.textContent = text;
  }

  function canvasJson() {
    return canvas.toJSON(["name", "selectable", "evented"]);
  }

  function ensureNames() {
    canvas.getObjects().forEach(function (o) {
      if (!o.name) o.set("name", uid());
    });
  }

  function utf8ToB64(str) {
    return btoa(unescape(encodeURIComponent(str)));
  }

  function b64ToUtf8(b64) {
    return decodeURIComponent(escape(atob(b64)));
  }

  function persistHotCache() {
    if (!canvas) return;
    try {
      localStorage.setItem(HOT, JSON.stringify({
        boardId: currentId,
        title: title(),
        digest: lastDigest,
        json: canvasJson()
      }));
    } catch (e) { /* quota — BACK is the durable copy */ }
  }

  function scheduleSave() {
    persistHotCache();
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveVersion, DEBOUNCE_MS);
    setStatus("pending version… (debounce " + DEBOUNCE_MS / 1000 + "s)");
  }

  function saveVersion() {
    if (!canvas) return Promise.resolve();
    ensureNames();
    var json = canvasJson();
    var bytes = utf8ToB64(JSON.stringify(json));
    return rpc("POST", "/canvas/blob", {
      operationId: opId("blob"),
      bytes: bytes,
      date: new Date().toISOString().slice(0, 10),
      name: title() + ".json",
      description: "fabric canvas version"
    }).then(function (env) {
      if (env.ok === false) {
        setStatus("blob.put refused: " + (env.reason || "unknown"));
        return env;
      }
      lastDigest = env.digest;
      persistHotCache();
      setStatus(lastDigest);
      return rpc("POST", "/canvas/boards", {
        operationId: opId("board"),
        id: currentId,
        title: title(),
        blobDigest: lastDigest
      }).then(function (b) {
        if (b.ok === false) {
          setStatus("board.put refused: " + (b.reason || "unknown") + " — " + lastDigest);
          return b;
        }
        if (b.id) currentId = b.id;
        setStatus(lastDigest);
        return refreshBoards();
      });
    });
  }

  function loadJson(json) {
    restoring = true;
    var done = function () {
      ensureNames();
      canvas.requestRenderAll();
      restoring = false;
      renderLayers();
      syncProps();
    };
    var ret = canvas.loadFromJSON(json);
    if (ret && typeof ret.then === "function") return ret.then(done);
    return Promise.resolve().then(done);
  }

  function reloadByDigest(digest) {
    if (!digest) return Promise.resolve();
    return rpc("GET", "/canvas/blob?digest=" + encodeURIComponent(digest)).then(function (env) {
      if (env.ok === false) {
        setStatus("blob.get refused: " + (env.reason || "unknown"));
        return;
      }
      var raw = b64ToUtf8(env.bytes);
      lastDigest = env.digest || digest;
      return loadJson(JSON.parse(raw)).then(function () {
        history = [JSON.stringify(canvasJson())];
        historyIndex = 0;
        setStatus(lastDigest);
      });
    });
  }

  function pushHistory() {
    if (restoring || !canvas) return;
    ensureNames();
    var snap = JSON.stringify(canvasJson());
    history = history.slice(0, historyIndex + 1);
    history.push(snap);
    if (history.length > 40) history.shift();
    historyIndex = history.length - 1;
    scheduleSave();
    renderLayers();
  }

  function restore(snap) {
    loadJson(JSON.parse(snap));
  }

  var TEMPLATES = {
    blank: function () {
      return { width: 900, height: 1200, background: "#ffffff", objects: [] };
    },
    poster: function () {
      return {
        width: 900, height: 1200, background: "#111827",
        objects: [
          { type: "Rect", left: 48, top: 48, width: 804, height: 1104, fill: "#1f2937", rx: 12, ry: 12, name: uid() },
          { type: "IText", left: 80, top: 160, text: "POSTER", fill: "#f9fafb", fontSize: 72, fontFamily: "Impact", fontWeight: "bold", name: uid() },
          { type: "IText", left: 80, top: 260, text: "A shared canvas.", fill: "#a5b4fc", fontSize: 28, fontFamily: "Georgia", name: uid() }
        ]
      };
    },
    card: function () {
      return {
        width: 900, height: 600, background: "#fef3c7",
        objects: [
          { type: "Circle", left: 620, top: -40, radius: 180, fill: "#f59e0b", name: uid() },
          { type: "IText", left: 70, top: 200, text: "You're invited", fill: "#78350f", fontSize: 56, fontFamily: "Georgia", name: uid() },
          { type: "IText", left: 70, top: 280, text: "Saturday · 7pm", fill: "#92400e", fontSize: 24, name: uid() }
        ]
      };
    },
    social: function () {
      return {
        width: 1080, height: 1080, background: "#0ea5e9",
        objects: [
          { type: "Rect", left: 60, top: 60, width: 960, height: 960, fill: "#0284c7", name: uid() },
          { type: "IText", left: 100, top: 420, text: "SHIP IT", fill: "#ffffff", fontSize: 96, fontFamily: "Impact", name: uid() },
          { type: "IText", left: 100, top: 540, text: "sharedai.space", fill: "#e0f2fe", fontSize: 32, name: uid() }
        ]
      };
    }
  };

  // Fabric 7.4.0 UMD puts classes on `fabric` as getters. Reading
  // fabric.Canvas *calls* the class without `new`. Take the descriptor.
  function Fab(name) {
    var ns = window.fabric;
    if (!ns) throw new Error("fabric missing");
    var d = Object.getOwnPropertyDescriptor(ns, name);
    if (d && typeof d.get === "function") {
      try {
        var v = d.get();
        if (typeof v === "function") return v;
      } catch (e) {
        return d.get;
      }
      return d.get;
    }
    if (d && d.value) return d.value;
    return ns[name];
  }

  // Fabric 7 treats `type` as a getter. Passing type in the options bag
  // throws "Cannot set property type ... which has only a getter".
  function withoutType(o) {
    var copy = {};
    if (!o) return copy;
    Object.keys(o).forEach(function (k) {
      if (k !== "type") copy[k] = o[k];
    });
    return copy;
  }

  function makeObject(o) {
    var spec = withoutType(o);
    var t = String((o && o.type) || "").toLowerCase();
    if (t === "rect") return new (Fab("Rect"))(spec);
    if (t === "circle") return new (Fab("Circle"))(spec);
    if (t === "triangle") return new (Fab("Triangle"))(spec);
    if (t === "line") return new (Fab("Line"))([50, 50, 280, 50], spec);
    if (t === "i-text" || t === "itext" || t === "text") {
      return new (Fab("IText"))(o.text || spec.text || "", spec);
    }
    return new (Fab("IText"))(o.text || spec.text || "object", spec);
  }

  function applyTemplate(key) {
    var spec = TEMPLATES[key]();
    restoring = true;
    if (canvas.setDimensions) {
      canvas.setDimensions({ width: spec.width, height: spec.height });
    } else {
      if (canvas.setWidth) canvas.setWidth(spec.width);
      if (canvas.setHeight) canvas.setHeight(spec.height);
    }
    canvas.clear();
    canvas.backgroundColor = spec.background;
    spec.objects.forEach(function (o) { canvas.add(makeObject(o)); });
    canvas.requestRenderAll();
    restoring = false;
    pushHistory();
  }

  function addText(text, size, weight) {
    var t = new (Fab("IText"))(text, {
      left: 120, top: 160, fill: "#111827", fontSize: size,
      fontFamily: "Inter, system-ui, sans-serif", fontWeight: weight || "normal",
      name: uid()
    });
    canvas.add(t);
    canvas.setActiveObject(t);
    pushHistory();
  }

  function addShape(kind) {
    var obj;
    if (kind === "rect") obj = new (Fab("Rect"))({ left: 140, top: 180, width: 220, height: 140, fill: "#7c5cff", name: uid() });
    if (kind === "circle") obj = new (Fab("Circle"))({ left: 180, top: 200, radius: 80, fill: "#22d3ee", name: uid() });
    if (kind === "triangle") obj = new (Fab("Triangle"))({ left: 180, top: 200, width: 160, height: 140, fill: "#f59e0b", name: uid() });
    if (kind === "line") obj = new (Fab("Line"))([50, 50, 280, 50], { left: 160, top: 240, stroke: "#111827", strokeWidth: 4, name: uid() });
    if (obj) {
      canvas.add(obj);
      canvas.setActiveObject(obj);
      pushHistory();
    }
  }

  function selected() { return canvas.getActiveObject(); }

  function syncProps() {
    var obj = selected();
    var form = document.getElementById("propForm");
    var hint = document.getElementById("selHint");
    if (!obj) {
      form.classList.add("hidden");
      hint.classList.remove("hidden");
      return;
    }
    hint.classList.add("hidden");
    form.classList.remove("hidden");
    var fill = obj.fill;
    if (typeof fill === "string" && fill[0] === "#") document.getElementById("fillColor").value = fill.slice(0, 7);
    document.getElementById("opacity").value = obj.opacity == null ? 1 : obj.opacity;
    document.getElementById("strokeWidth").value = obj.strokeWidth || 0;
    if (obj.fontSize) document.getElementById("fontSize").value = obj.fontSize;
    if (obj.fontFamily) document.getElementById("fontFamily").value = obj.fontFamily.split(",")[0];
  }

  function renderLayers() {
    var ul = document.getElementById("layerList");
    ul.innerHTML = "";
    var objs = canvas.getObjects().slice().reverse();
    var active = selected();
    objs.forEach(function (o, i) {
      var li = document.createElement("li");
      if (o === active) li.classList.add("active");
      var label = o.text ? o.text.slice(0, 24) : (o.name || o.type || "object");
      li.textContent = (objs.length - i) + ". " + label;
      li.addEventListener("click", function () {
        canvas.setActiveObject(o);
        canvas.requestRenderAll();
        syncProps();
        renderLayers();
      });
      ul.appendChild(li);
    });
  }

  function download(name, href) {
    var a = document.createElement("a");
    a.href = href;
    a.download = name;
    a.click();
  }

  function refreshBoards() {
    return rpc("GET", "/canvas/boards").then(function (env) {
      var list = env["@graph"] || env.result || [];
      if (!Array.isArray(list)) list = [];
      boards = list;
      var sel = document.getElementById("projectSelect");
      sel.innerHTML = "";
      boards.forEach(function (p) {
        var opt = document.createElement("option");
        opt.value = p.id;
        opt.textContent = p.title || ("board " + p.id);
        if (String(p.id) === String(currentId)) opt.selected = true;
        sel.appendChild(opt);
      });
      if (!currentId && boards[0]) currentId = boards[0].id;
    });
  }

  function newBoard() {
    currentId = null;
    lastDigest = null;
    document.getElementById("projectName").value = "Untitled";
    applyTemplate("blank");
  }

  function openBoard(id) {
    var p = boards.find(function (b) { return String(b.id) === String(id); });
    currentId = id;
    if (p) {
      document.getElementById("projectName").value = p.title || "";
      if (p.blobDigest) return reloadByDigest(p.blobDigest);
    }
    applyTemplate("blank");
    return Promise.resolve();
  }

  function initCanvas() {
    canvas = new (Fab("Canvas"))("c", {
      backgroundColor: "#ffffff",
      preserveObjectStacking: true
    });
    var PencilBrush = Fab("PencilBrush");
    if (typeof PencilBrush === "function") canvas.freeDrawingBrush = new PencilBrush(canvas);
    canvas.on("object:modified", pushHistory);
    canvas.on("object:added", function () { if (!restoring) pushHistory(); });
    canvas.on("selection:created", function () { syncProps(); renderLayers(); });
    canvas.on("selection:updated", function () { syncProps(); renderLayers(); });
    canvas.on("selection:cleared", function () { syncProps(); renderLayers(); });
  }

  function bindUi() {
    document.querySelectorAll(".rail-btn").forEach(function (btn) {
      btn.addEventListener("click", function () {
        document.querySelectorAll(".rail-btn").forEach(function (b) { b.classList.remove("active"); });
        btn.classList.add("active");
        var panel = btn.getAttribute("data-panel");
        document.querySelectorAll("[data-panel-body]").forEach(function (el) {
          el.classList.toggle("hidden", el.getAttribute("data-panel-body") !== panel);
        });
      });
    });

    var grid = document.getElementById("templateGrid");
    [["blank", "Blank"], ["poster", "Poster"], ["card", "Card"], ["social", "Social"]].forEach(function (t) {
      var b = document.createElement("button");
      b.type = "button";
      b.className = "template-card";
      b.textContent = t[1];
      b.addEventListener("click", function () { applyTemplate(t[0]); });
      grid.appendChild(b);
    });

    document.getElementById("addHeading").onclick = function () { addText("Heading", 56, "bold"); };
    document.getElementById("addSubhead").onclick = function () { addText("Subheading", 32, "600"); };
    document.getElementById("addBody").onclick = function () { addText("Body text", 18, "normal"); };
    document.querySelectorAll("[data-shape]").forEach(function (b) {
      b.addEventListener("click", function () { addShape(b.getAttribute("data-shape")); });
    });

    document.getElementById("drawMode").addEventListener("change", function (e) {
      canvas.isDrawingMode = e.target.checked;
      if (canvas.freeDrawingBrush) {
        canvas.freeDrawingBrush.width = Number(document.getElementById("brushSize").value);
        canvas.freeDrawingBrush.color = document.getElementById("brushColor").value;
      }
    });
    document.getElementById("brushSize").oninput = function (e) {
      if (canvas.freeDrawingBrush) canvas.freeDrawingBrush.width = Number(e.target.value);
    };
    document.getElementById("brushColor").oninput = function (e) {
      if (canvas.freeDrawingBrush) canvas.freeDrawingBrush.color = e.target.value;
    };

    document.getElementById("imageFile").addEventListener("change", function (e) {
      var file = e.target.files && e.target.files[0];
      if (!file) return;
      var reader = new FileReader();
      reader.onload = function () {
        var Img = Fab("FabricImage") || Fab("Image");
        var added = function (img) {
          if (img.scaleToWidth) img.scaleToWidth(360);
          img.set("name", uid());
          canvas.add(img);
          canvas.setActiveObject(img);
          pushHistory();
        };
        var ret = Img.fromURL(reader.result);
        if (ret && typeof ret.then === "function") ret.then(added);
        else Img.fromURL(reader.result, added);
      };
      reader.readAsDataURL(file);
      e.target.value = "";
    });

    function setProp(key, val) {
      var o = selected(); if (!o) return;
      o.set(key, val); canvas.requestRenderAll();
    }
    document.getElementById("fillColor").oninput = function (e) { setProp("fill", e.target.value); };
    document.getElementById("strokeColor").oninput = function (e) { setProp("stroke", e.target.value); };
    document.getElementById("strokeWidth").oninput = function (e) { setProp("strokeWidth", Number(e.target.value)); };
    document.getElementById("opacity").oninput = function (e) { setProp("opacity", Number(e.target.value)); };
    document.getElementById("fontFamily").onchange = function (e) { setProp("fontFamily", e.target.value); };
    document.getElementById("fontSize").onchange = function (e) { setProp("fontSize", Number(e.target.value)); };

    document.getElementById("bringFwd").onclick = function () {
      var o = selected(); if (!o) return;
      if (canvas.bringObjectForward) canvas.bringObjectForward(o);
      else if (o.bringForward) o.bringForward();
      pushHistory();
    };
    document.getElementById("sendBack").onclick = function () {
      var o = selected(); if (!o) return;
      if (canvas.sendObjectBackwards) canvas.sendObjectBackwards(o);
      else if (o.sendBackwards) o.sendBackwards();
      pushHistory();
    };
    document.getElementById("dup").onclick = function () {
      var o = selected(); if (!o) return;
      var place = function (c) {
        c.set({ left: (o.left || 0) + 24, top: (o.top || 0) + 24, name: uid() });
        canvas.add(c);
        pushHistory();
      };
      var ret = o.clone();
      if (ret && typeof ret.then === "function") ret.then(place);
      else o.clone(place);
    };
    document.getElementById("lock").onclick = function () {
      var o = selected(); if (!o) return;
      var locked = !o.selectable;
      o.set({ selectable: locked, evented: locked });
      canvas.discardActiveObject(); canvas.requestRenderAll();
    };

    document.getElementById("btnUndo").onclick = function () {
      if (historyIndex <= 0) return;
      historyIndex -= 1;
      restore(history[historyIndex]);
    };
    document.getElementById("btnRedo").onclick = function () {
      if (historyIndex >= history.length - 1) return;
      historyIndex += 1;
      restore(history[historyIndex]);
    };
    document.getElementById("btnDelete").onclick = function () {
      var o = selected(); if (!o) return;
      canvas.remove(o); pushHistory();
    };
    document.getElementById("btnNew").onclick = function () { newBoard(); };

    function taskOut(obj) {
      document.getElementById("taskOut").textContent = typeof obj === "string" ? obj : JSON.stringify(obj, null, 2);
    }
    document.getElementById("taskForm").onclick = function () {
      rpc("POST", "/canvas/ui/surface", {
        operationId: opId("ui"),
        taskKind: "task.form",
        title: "J1",
        stepKind: "decide",
        fields: [{ name: "decision", datatype: "enum", ordinal: 1, enum_key: "approve-deny" }]
      }).then(taskOut);
    };
    document.getElementById("taskDate").onclick = function () {
      rpc("POST", "/canvas/ui/surface", {
        operationId: opId("ui"),
        taskKind: "task.date",
        catalogVersion: "ghis-20@1",
        fields: [{ name: "due_on", datatype: "date", ordinal: 1 }]
      }).then(taskOut);
    };
    document.getElementById("taskDate19").onclick = function () {
      rpc("POST", "/canvas/ui/surface", {
        operationId: opId("ui"),
        taskKind: "task.date",
        catalogVersion: "ghis-19@1",
        fields: [{ name: "due_on", datatype: "date", ordinal: 1 }]
      }).then(taskOut);
    };
    document.getElementById("taskPreview").onclick = function () {
      if (!lastDigest) { taskOut("save a canvas version first (digest is the name)"); return; }
      rpc("POST", "/canvas/ui/surface", {
        operationId: opId("ui"),
        taskKind: "task.preview",
        blobDigest: lastDigest
      }).then(taskOut);
    };

    var modal = document.getElementById("editorModal");
    document.getElementById("btnEditor").onclick = function () {
      rpc("POST", "/canvas/front/path", {
        operationId: opId("front"),
        path: "front.modal.editor",
        verb: "open"
      });
      if (modal && modal.showModal) modal.showModal();
    };
    document.getElementById("editorRun").onclick = function () {
      var src = document.getElementById("editorSource").value;
      rpc("POST", "/canvas/script/run", {
        operationId: opId("script"),
        source: src,
        speaker: "actor"
      }).then(function (env) {
        document.getElementById("editorOut").textContent = JSON.stringify(env, null, 2);
      });
    };
    document.getElementById("projectSelect").onchange = function (e) { openBoard(e.target.value); };
    document.getElementById("projectName").onchange = scheduleSave;

    function exportName(ext) { return title() + "." + ext; }
    document.getElementById("btnPng").onclick = function () {
      download(exportName("png"), canvas.toDataURL({ format: "png" }));
    };
    document.getElementById("btnJpg").onclick = function () {
      download(exportName("jpg"), canvas.toDataURL({ format: "jpeg", quality: 0.92 }));
    };
    document.getElementById("btnSvg").onclick = function () {
      var blob = new Blob([canvas.toSVG()], { type: "image/svg+xml" });
      download(exportName("svg"), URL.createObjectURL(blob));
    };
    document.getElementById("btnJson").onclick = function () {
      var blob = new Blob([JSON.stringify(canvasJson(), null, 2)], { type: "application/json" });
      download(exportName("json"), URL.createObjectURL(blob));
    };

    function setZoom(z) {
      zoom = Math.max(0.25, Math.min(2.5, z));
      canvas.setZoom(zoom);
      document.getElementById("zoomLabel").textContent = Math.round(zoom * 100) + "%";
    }
    document.getElementById("zoomIn").onclick = function () { setZoom(zoom + 0.1); };
    document.getElementById("zoomOut").onclick = function () { setZoom(zoom - 0.1); };
    document.getElementById("zoomFit").onclick = function () { setZoom(1); };

    document.addEventListener("keydown", function (e) {
      if ((e.metaKey || e.ctrlKey) && e.key === "z") {
        e.preventDefault();
        if (e.shiftKey) document.getElementById("btnRedo").click();
        else document.getElementById("btnUndo").click();
      }
      if ((e.key === "Backspace" || e.key === "Delete") && !/INPUT|TEXTAREA|SELECT/.test(e.target.tagName)) {
        if (selected() && selected().isEditing) return;
        document.getElementById("btnDelete").click();
      }
    });
  }

  function boot() {
    if (typeof fabric === "undefined") {
      document.body.innerHTML = "<p style='padding:2rem'>Fabric.js 7.4.0 failed to load from the vendored copy.</p>";
      return;
    }
    initCanvas();
    bindUi();
    refreshBoards().then(function () {
      if (boards.length && boards[0].blobDigest) {
        document.getElementById("projectName").value = boards[0].title || "";
        currentId = boards[0].id;
        return reloadByDigest(boards[0].blobDigest);
      }
      try {
        var hot = JSON.parse(localStorage.getItem(HOT) || "null");
        if (hot && hot.json) {
          currentId = hot.boardId;
          lastDigest = hot.digest;
          if (hot.title) document.getElementById("projectName").value = hot.title;
          return loadJson(hot.json).then(function () {
            history = [JSON.stringify(canvasJson())];
            historyIndex = 0;
            setStatus(lastDigest ? lastDigest + " (hot cache)" : "hot cache, not yet a digest");
          });
        }
      } catch (e) { /* ignore */ }
      newBoard();
    });
  }

  boot();
})();
