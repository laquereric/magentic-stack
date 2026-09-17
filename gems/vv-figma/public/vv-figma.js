/* vv-figma — single browser load for every Figma-specific call.
 *
 * Editor.js loads this file and talks in Effects. It must not call
 * `figma` / `window.figma`, scrape figma.com's DOM, or reimplement
 * node mapping.
 *
 *   <script src="/vv-figma.js"></script>
 *   VvFigma.mount({ onEvent: function (evt) { scheduleSave(); } });
 *   VvFigma.applyEffect({ op: "create", item: { type: "rectangle", name: "UC" } });
 *
 * Never raises: every public method returns a Promise of
 * { ok: true, data } or { ok: false, reason, because }.
 *
 * Plugin sandbox has the `figma` global. The plugin UI iframe does not;
 * it postMessages Effects to code.js.
 */
(function (root) {
  "use strict";

  var VERSION = "0.1.0";
  var EMBED_BASE = "https://www.figma.com/embed";
  var FILE_URL_BASE = "https://www.figma.com/file";

  var CREATE = {
    rectangle: "createRectangle",
    ellipse: "createEllipse",
    text: "createText",
    frame: "createFrame",
    line: "createLine",
    star: "createStar",
    polygon: "createPolygon"
  };

  var KIND = {
    selectionchange: "select",
    currentpagechange: "page",
    documentchange: "update",
    close: "close"
  };

  var state = {
    mounted: false,
    mode: null,
    handlers: [],
    opts: null,
    embedFrame: null,
    uiHandlers: {}
  };

  function ok(data, extra) {
    var out = { ok: true, data: data == null ? null : data };
    if (extra) {
      Object.keys(extra).forEach(function (k) {
        if (extra[k] != null) out[k] = extra[k];
      });
    }
    return out;
  }

  function refuse(reason, because, extra) {
    var out = { ok: false, reason: String(reason), because: String(because || "") };
    if (extra) {
      Object.keys(extra).forEach(function (k) {
        if (extra[k] != null) out[k] = extra[k];
      });
    }
    return out;
  }

  function plugin() {
    return typeof figma !== "undefined" && figma && typeof figma.createRectangle === "function"
      ? figma
      : null;
  }

  function context() {
    if (plugin()) return "plugin";
    if (state.mode === "embed" && state.embedFrame) return "embed";
    if (state.mode === "ui") return "ui";
    return "none";
  }

  function emit(evt) {
    state.handlers.slice().forEach(function (fn) {
      try { fn(evt); } catch (e) { /* listener errors stay in the listener */ }
    });
    if (state.opts && typeof state.opts.onEvent === "function") {
      try { state.opts.onEvent(evt); } catch (e) { /* same */ }
    }
  }

  function guard(fn) {
    return Promise.resolve()
      .then(fn)
      .then(function (value) {
        if (value && typeof value === "object" && Object.prototype.hasOwnProperty.call(value, "ok")) {
          return value;
        }
        return ok(value);
      })
      .catch(function (e) {
        var msg = e && e.message ? e.message : String(e);
        return refuse("figma_error", msg);
      });
  }

  function needPlugin() {
    if (!plugin()) return refuse("plugin_required", "Figma Plugin API is not loaded (figma.createRectangle missing)");
    return null;
  }

  function plainNode(node) {
    if (!node || typeof node !== "object") return node;
    return {
      id: node.id,
      type: node.type,
      name: node.name,
      x: node.x,
      y: node.y,
      width: node.width,
      height: node.height
    };
  }

  function applyGeometry(node, item) {
    if (item.x != null) node.x = Number(item.x);
    if (item.y != null) node.y = Number(item.y);
    if (item.width != null && node.resize) node.resize(Number(item.width), Number(item.height || node.height || 1));
    else if (item.height != null && node.resize) node.resize(Number(node.width || 1), Number(item.height));
    if (item.name) node.name = String(item.name);
    if (item.fills) node.fills = item.fills;
  }

  function applyEffect(effect) {
    return guard(function () {
      if (!effect || typeof effect !== "object") {
        return refuse("op_required", "applyEffect needs an Effect object");
      }
      var op = String(effect.op || "");
      if (!op) return refuse("op_required", "an Effect needs op:");
      var item = effect.item || {};

      if (context() === "ui") {
        if (typeof parent !== "undefined" && parent.postMessage) {
          parent.postMessage({ pluginMessage: { kind: "effect", effect: effect } }, "*");
          return ok({ forwarded: true, op: op });
        }
        return refuse("plugin_required", "plugin UI cannot apply Effects without a sandbox");
      }

      var missing = needPlugin();
      if (missing) return missing;
      var f = plugin();

      if (op === "broadcast") {
        if (f.ui && typeof f.ui.postMessage === "function") {
          f.ui.postMessage({ kind: "broadcast", event: effect.event, payload: effect.payload });
          return ok({ event: effect.event || "vv-figma" });
        }
        return refuse("broadcast_rest_unsupported", "plugin UI is not open");
      }

      if (op === "create") {
        var method = CREATE[item.type];
        if (item.type === "group") {
          return refuse("item_type_unsupported", "create group from a selection; not a lone constructor");
        }
        if (!method || typeof f[method] !== "function") {
          return refuse("item_type_unsupported", "unknown or unsupported item type " + JSON.stringify(item.type));
        }
        var node = f[method]();
        applyGeometry(node, item);
        if (item.type === "text" && item.characters && typeof f.loadFontAsync === "function") {
          var font = node.fontName || { family: "Inter", style: "Regular" };
          return f.loadFontAsync(font).then(function () {
            node.characters = String(item.characters || item.content || item.title || "");
            if (f.currentPage) f.currentPage.appendChild(node);
            return ok(plainNode(node));
          });
        }
        if (f.currentPage) f.currentPage.appendChild(node);
        return ok(plainNode(node));
      }

      if (op === "update" || op === "sync") {
        if (!item.id) return refuse("item_id_required", "update/sync needs item.id");
        var found = f.getNodeById && f.getNodeById(String(item.id));
        if (!found) return refuse("item_id_required", "no node with id " + item.id);
        applyGeometry(found, item);
        return ok(plainNode(found));
      }

      if (op === "delete") {
        if (!item.id) return refuse("item_id_required", "delete needs item.id");
        var doomed = f.getNodeById && f.getNodeById(String(item.id));
        if (!doomed) return refuse("item_id_required", "no node with id " + item.id);
        doomed.remove();
        return ok({ id: String(item.id) });
      }

      return refuse("op_unsupported", "unknown Effect op " + JSON.stringify(op));
    });
  }

  function bindPluginEvents() {
    var f = plugin();
    if (!f || typeof f.on !== "function") return;
    Object.keys(KIND).forEach(function (name) {
      var fn = function () {
        emit({ kind: KIND[name], event: name });
      };
      f.on(name, fn);
      state.uiHandlers[name] = fn;
    });
    if (f.ui) {
      f.ui.onmessage = function (msg) {
        if (msg && msg.kind === "effect" && msg.effect) applyEffect(msg.effect);
        else if (msg) emit({ kind: msg.kind || "message", payload: msg });
      };
    }
  }

  function unbindPluginEvents() {
    var f = plugin();
    if (!f || typeof f.off !== "function") return;
    Object.keys(state.uiHandlers).forEach(function (name) {
      try { f.off(name, state.uiHandlers[name]); } catch (e) { /* */ }
    });
    state.uiHandlers = {};
  }

  function embed(host, fileKey, opts) {
    opts = opts || {};
    return guard(function () {
      if (!fileKey) return refuse("file_required", "embed needs a file_key");
      if (!host) return refuse("dest_required", "embed needs a host element");
      var el = typeof host === "string" ? document.getElementById(host) : host;
      if (!el) return refuse("dest_required", "embed host was not found");
      var url = EMBED_BASE + "?embed_host=" + encodeURIComponent(opts.embedHost || "figma") +
        "&url=" + encodeURIComponent(FILE_URL_BASE + "/" + fileKey);
      var iframe = document.createElement("iframe");
      iframe.src = url;
      iframe.width = String(opts.width || 800);
      iframe.height = String(opts.height || 450);
      iframe.setAttribute("allowfullscreen", "true");
      el.appendChild(iframe);
      state.embedFrame = iframe;
      state.mounted = true;
      state.mode = "embed";
      return ok({ mode: "embed", src: url });
    });
  }

  function mount(opts) {
    opts = opts || {};
    return guard(function () {
      state.opts = opts;
      var mode = opts.mode || (plugin() ? "plugin" : (opts.fileKey || opts.file_key ? "embed" : "plugin"));
      if (mode === "embed") {
        return embed(opts.host, opts.fileKey || opts.file_key, opts);
      }
      if (mode === "ui") {
        state.mounted = true;
        state.mode = "ui";
        if (typeof window !== "undefined") {
          window.onmessage = function (ev) {
            var msg = ev && ev.data && ev.data.pluginMessage;
            if (msg) emit({ kind: msg.kind || "message", payload: msg });
          };
        }
        emit({ kind: "connect", mode: "ui" });
        return ok({ mode: "ui" });
      }
      var missing = needPlugin();
      if (missing) return missing;
      unbindPluginEvents();
      bindPluginEvents();
      state.mounted = true;
      state.mode = "plugin";
      emit({ kind: "connect", mode: "plugin" });
      return ok({ mode: "plugin" });
    });
  }

  function unmount() {
    return guard(function () {
      unbindPluginEvents();
      if (state.embedFrame && state.embedFrame.parentNode) {
        state.embedFrame.parentNode.removeChild(state.embedFrame);
      }
      state.embedFrame = null;
      state.mounted = false;
      state.mode = null;
      return ok({ unmounted: true });
    });
  }

  function on(fn) {
    if (typeof fn === "function") state.handlers.push(fn);
    return ok({ n: state.handlers.length });
  }

  root.VvFigma = {
    VERSION: VERSION,
    mount: mount,
    unmount: unmount,
    on: on,
    applyEffect: applyEffect,
    embed: embed,
    context: context
  };
})(typeof window !== "undefined" ? window : (typeof global !== "undefined" ? global : this));
