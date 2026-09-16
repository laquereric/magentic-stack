/* VvUseCase — Use-Case 3.0 Essentials Fabric plugin.
 * Overlay Stage owns canvas / history / scheduleSave.
 * This file must not call the Miro SDK or reimplement envelope.
 *
 *   VvUseCase.attach({ canvas, Fab, uid, pushHistory, journalPath });
 *   VvUseCase.template();
 *   VvUseCase.makeObject(o);
 */
(function (root) {
  "use strict";

  var TO_JSON_KEYS = ["ucKind", "ucId", "ucRole", "ucFrom", "ucTo", "ucStereotype"];
  var host = null;
  var pick = null;

  function Fab(name) {
    if (host && typeof host.Fab === "function") return host.Fab(name);
    var ns = root.fabric;
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

  function uid() {
    if (host && typeof host.uid === "function") return host.uid();
    return "uc_" + Math.random().toString(36).slice(2, 10);
  }

  function canvas() {
    return host && host.canvas;
  }

  function pushHistory() {
    if (host && typeof host.pushHistory === "function") host.pushHistory();
  }

  function journalPath(path, verb, payload) {
    if (host && typeof host.journalPath === "function") host.journalPath(path, verb, payload);
  }

  function withoutType(o) {
    var copy = {};
    if (!o) return copy;
    Object.keys(o).forEach(function (k) {
      if (k !== "type") copy[k] = o[k];
    });
    return copy;
  }

  function tag(obj, kind, extra) {
    obj.set("ucKind", kind);
    if (extra) {
      Object.keys(extra).forEach(function (k) {
        if (extra[k] != null) obj.set(k, extra[k]);
      });
    }
    if (!obj.name) obj.set("name", uid());
    return obj;
  }

  function addToCanvas(obj) {
    var c = canvas();
    if (!c || !obj) return obj;
    c.add(obj);
    if (c.setActiveObject) c.setActiveObject(obj);
    if (c.requestRenderAll) c.requestRenderAll();
    pushHistory();
    journalPath("front.canvas", "add_usecase", obj.ucKind || "object");
    return obj;
  }

  function buildActor(opts) {
    opts = opts || {};
    var Circle = Fab("Circle");
    var Line = Fab("Line");
    var IText = Fab("IText");
    var Group = Fab("Group");
    var label = opts.label || "Actor";
    var head = new Circle({
      radius: 14, left: -14, top: -58, fill: "#111827",
      originX: "left", originY: "top"
    });
    var body = new Line([0, -30, 0, 16], { stroke: "#111827", strokeWidth: 3 });
    var arms = new Line([-22, -8, 22, -8], { stroke: "#111827", strokeWidth: 3 });
    var legL = new Line([0, 16, -16, 48], { stroke: "#111827", strokeWidth: 3 });
    var legR = new Line([0, 16, 16, 48], { stroke: "#111827", strokeWidth: 3 });
    var text = new IText(label, {
      left: -48, top: 52, fontSize: 16, fontFamily: "Inter, system-ui, sans-serif",
      fill: "#111827", originX: "left", originY: "top"
    });
    var g = new Group([head, body, arms, legL, legR, text], {
      left: opts.left == null ? 80 : opts.left,
      top: opts.top == null ? 360 : opts.top
    });
    return tag(g, "actor", { ucId: opts.ucId || uid(), ucRole: opts.role || "primary" });
  }

  function buildUseCase(opts) {
    opts = opts || {};
    var Ellipse = Fab("Ellipse");
    var IText = Fab("IText");
    var Group = Fab("Group");
    var label = opts.label || "Use case";
    var rx = opts.rx || 110;
    var ry = opts.ry || 44;
    var oval = new Ellipse({
      rx: rx, ry: ry, left: -rx, top: -ry,
      fill: "#ffffff", stroke: "#111827", strokeWidth: 2,
      originX: "left", originY: "top"
    });
    var text = new IText(label, {
      left: -rx + 16, top: -10, fontSize: 16,
      fontFamily: "Inter, system-ui, sans-serif", fill: "#111827"
    });
    var g = new Group([oval, text], {
      left: opts.left == null ? 400 : opts.left,
      top: opts.top == null ? 320 : opts.top
    });
    return tag(g, "usecase", { ucId: opts.ucId || uid() });
  }

  function buildSystem(opts) {
    opts = opts || {};
    var Rect = Fab("Rect");
    var IText = Fab("IText");
    var Group = Fab("Group");
    var w = opts.width || 520;
    var h = opts.height || 640;
    var box = new Rect({
      left: 0, top: 0, width: w, height: h,
      fill: "rgba(124,92,255,0.04)", stroke: "#111827", strokeWidth: 2,
      originX: "left", originY: "top"
    });
    var text = new IText(opts.label || "System of interest", {
      left: 16, top: 12, fontSize: 18, fontWeight: "600",
      fontFamily: "Inter, system-ui, sans-serif", fill: "#111827"
    });
    var g = new Group([box, text], {
      left: opts.left == null ? 280 : opts.left,
      top: opts.top == null ? 160 : opts.top
    });
    return tag(g, "system", { ucId: opts.ucId || uid() });
  }

  function buildAssociation(fromObj, toObj, opts) {
    opts = opts || {};
    if (!fromObj || !toObj) return null;
    var Line = Fab("Line");
    var a = fromObj.getCenterPoint ? fromObj.getCenterPoint() : { x: fromObj.left, y: fromObj.top };
    var b = toObj.getCenterPoint ? toObj.getCenterPoint() : { x: toObj.left, y: toObj.top };
    var line = new Line([a.x, a.y, b.x, b.y], {
      stroke: "#111827", strokeWidth: 2,
      selectable: true
    });
    return tag(line, "association", {
      ucId: opts.ucId || uid(),
      ucFrom: fromObj.ucId || fromObj.name,
      ucTo: toObj.ucId || toObj.name,
      ucStereotype: opts.stereotype || null
    });
  }

  function addActor(opts) { return addToCanvas(buildActor(opts)); }
  function addUseCase(opts) { return addToCanvas(buildUseCase(opts)); }
  function addSystem(opts) { return addToCanvas(buildSystem(opts)); }
  function addAssociation(fromObj, toObj, opts) {
    return addToCanvas(buildAssociation(fromObj, toObj, opts));
  }

  function associateStart() {
    pick = { from: null };
    var c = canvas();
    if (c && c.discardActiveObject) {
      c.discardActiveObject();
      if (c.requestRenderAll) c.requestRenderAll();
    }
    if (document.body) document.body.classList.add("uc-pick");
  }

  function associateClick(obj) {
    if (!pick) return false;
    if (!obj || (obj.ucKind !== "actor" && obj.ucKind !== "usecase")) return true;
    if (!pick.from) {
      pick.from = obj;
      return true;
    }
    if (pick.from === obj) return true;
    var from = pick.from.ucKind === "actor" ? pick.from : obj;
    var to = pick.from.ucKind === "usecase" ? pick.from : obj;
    if (from.ucKind !== "actor" || to.ucKind !== "usecase") {
      pick.from = obj;
      return true;
    }
    addAssociation(from, to);
    pick = null;
    if (document.body) document.body.classList.remove("uc-pick");
    return true;
  }

  function primitive(o) {
    var spec = withoutType(o);
    var t = String((o && o.type) || "").toLowerCase();
    if (t === "rect") return new (Fab("Rect"))(spec);
    if (t === "circle") return new (Fab("Circle"))(spec);
    if (t === "ellipse") return new (Fab("Ellipse"))(spec);
    if (t === "triangle") return new (Fab("Triangle"))(spec);
    if (t === "line") {
      var pts = o.x1 != null ? [o.x1, o.y1, o.x2, o.y2] : [50, 50, 280, 50];
      return new (Fab("Line"))(pts, spec);
    }
    if (t === "i-text" || t === "itext" || t === "text") {
      return new (Fab("IText"))(o.text || spec.text || "", spec);
    }
    return null;
  }

  function makeObject(o) {
    if (!o) return new (Fab("IText"))("object", {});
    var kind = o.ucKind;
    var t = String(o.type || "").toLowerCase();
    if (kind === "actor" && t !== "group") {
      return buildActor({ label: o.text || o.label, left: o.left, top: o.top, ucId: o.ucId, role: o.ucRole });
    }
    if ((kind === "usecase" || t === "ellipse") && t !== "group") {
      if (kind === "usecase") {
        return buildUseCase({ label: o.text || o.label, left: o.left, top: o.top, ucId: o.ucId, rx: o.rx, ry: o.ry });
      }
      return primitive(o);
    }
    if (kind === "system" && t !== "group") {
      return buildSystem({ label: o.text || o.label, left: o.left, top: o.top, ucId: o.ucId, width: o.width, height: o.height });
    }
    if (t === "group") {
      var kids = (o.objects || []).map(function (child) {
        return primitive(child) || makeObject(child);
      });
      var g = new (Fab("Group"))(kids, withoutType(o));
      if (kind) tag(g, kind, { ucId: o.ucId, ucRole: o.ucRole });
      return g;
    }
    var built = primitive(o);
    if (built) {
      if (kind) tag(built, kind, { ucId: o.ucId, ucFrom: o.ucFrom, ucTo: o.ucTo, ucStereotype: o.ucStereotype, ucRole: o.ucRole });
      return built;
    }
    return new (Fab("IText"))(o.text || "object", withoutType(o));
  }

  function handles(o) {
    if (!o) return false;
    if (o.ucKind) return true;
    var t = String(o.type || "").toLowerCase();
    return t === "ellipse" || t === "group" || t === "actor" || t === "usecase" || t === "system";
  }

  function template() {
    return {
      width: 900,
      height: 1200,
      background: "#ffffff",
      objects: [
        { type: "system", ucKind: "system", ucId: "sys_1", label: "System of interest", left: 280, top: 160, width: 520, height: 640 },
        { type: "actor", ucKind: "actor", ucId: "act_1", ucRole: "primary", label: "Primary actor", left: 80, top: 360 },
        { type: "usecase", ucKind: "usecase", ucId: "uc_1", label: "Succeed at the goal", left: 400, top: 300 },
        { type: "usecase", ucKind: "usecase", ucId: "uc_2", label: "Handle an extension", left: 400, top: 460 }
      ]
    };
  }

  function applyTemplate(target) {
    var spec = template();
    var c = target || canvas();
    if (!c) return spec;
    if (c.setDimensions) c.setDimensions({ width: spec.width, height: spec.height });
    c.clear();
    c.backgroundColor = spec.background;
    var byId = {};
    spec.objects.forEach(function (o) {
      var obj = makeObject(o);
      if (!obj) return;
      c.add(obj);
      if (obj.ucId) byId[obj.ucId] = obj;
    });
    var as1 = buildAssociation(byId.act_1, byId.uc_1, { ucId: "as_1" });
    var as2 = buildAssociation(byId.act_1, byId.uc_2, { ucId: "as_2" });
    if (as1) c.add(as1);
    if (as2) c.add(as2);
    if (c.requestRenderAll) c.requestRenderAll();
    pushHistory();
    return spec;
  }

  function setLabel(obj, text) {
    if (!obj) return;
    if (obj.set && obj.text != null && !obj._objects) {
      obj.set("text", text);
    } else if (obj._objects) {
      var i;
      for (i = obj._objects.length - 1; i >= 0; i -= 1) {
        if (obj._objects[i].text != null) {
          obj._objects[i].set("text", text);
          break;
        }
      }
    }
    var c = canvas();
    if (c && c.requestRenderAll) c.requestRenderAll();
    pushHistory();
  }

  function attach(opts) {
    host = opts || {};
    var c = canvas();
    if (!c) return { ok: false, reason: "canvas_required" };
    c.on("mouse:down", function (ev) {
      if (!pick) return;
      var obj = ev && (ev.target || (ev.e && null));
      if (obj) associateClick(obj);
    });
    return { ok: true };
  }

  root.VvUseCase = {
    attach: attach,
    addActor: addActor,
    addUseCase: addUseCase,
    addSystem: addSystem,
    addAssociation: addAssociation,
    associateStart: associateStart,
    associateClick: associateClick,
    template: template,
    applyTemplate: applyTemplate,
    makeObject: makeObject,
    handles: handles,
    setLabel: setLabel,
    toJSONKeys: TO_JSON_KEYS
  };
})(typeof window !== "undefined" ? window : this);
