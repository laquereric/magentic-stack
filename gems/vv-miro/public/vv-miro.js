/* vv-miro — single browser load for every Miro-specific call.
 *
 * Editor.js (magentic-stack FRONT) loads this file and talks in
 * component events + Effects. It must not call window.miro, scrape
 * miro.com's DOM, or reimplement item mapping.
 *
 *   <script src="https://miro.com/app/static/sdk/v2/miro.js"></script>
 *   <script src="/vv-miro.js"></script>
 *   VvMiro.mount({ onEvent: function (evt) { scheduleSave(); } });
 *   VvMiro.applyEffect({ op: "create", item: { type: "app_card", title: "…" } });
 *
 * Never raises: every public method returns a Promise of
 * { ok: true, data } or { ok: false, reason, because }.
 */
(function (root) {
  "use strict";

  var VERSION = "0.1.0";
  var SDK_SRC = "https://miro.com/app/static/sdk/v2/miro.js";
  var LIVE_EMBED_BASE = "https://miro.com/app/live-embed";

  var CREATE = {
    app_card: "createAppCard",
    sticky_note: "createStickyNote",
    shape: "createShape",
    text: "createText",
    frame: "createFrame",
    connector: "createConnector",
    image: "createImage",
    card: "createCard",
    embed: "createEmbed",
    tag: "createTag"
  };

  var UI_EVENTS = [
    "drop",
    "icon:click",
    "app_card:open",
    "app_card:connect",
    "selection:update",
    "online_users:update",
    "items:create",
    "experimental:items:update",
    "items:delete"
  ];

  var KIND = {
    "drop": "drop",
    "icon:click": "icon_click",
    "app_card:open": "app_card_open",
    "app_card:connect": "app_card_connect",
    "selection:update": "select",
    "online_users:update": "online_users",
    "items:create": "create",
    "experimental:items:update": "update",
    "items:delete": "delete"
  };

  var state = {
    mounted: false,
    mode: null,
    handlers: [],
    uiHandlers: {},
    broadcastHandler: null,
    opts: null,
    embedFrame: null
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

  function blank(v) {
    return v == null || String(v).trim() === "";
  }

  function board() {
    var miro = root.miro;
    return miro && miro.board ? miro.board : null;
  }

  function context() {
    if (board()) return "sdk";
    if (state.mode === "embed" && state.embedFrame) return "embed";
    return "none";
  }

  function plainItem(item) {
    if (!item || typeof item !== "object") return item;
    var out = {};
    Object.keys(item).forEach(function (k) {
      var v = item[k];
      if (typeof v === "function") return;
      out[k] = v;
    });
    return out;
  }

  function plainItems(list) {
    if (!list) return [];
    return (Array.isArray(list) ? list : [list]).map(plainItem);
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
        return refuse("miro_error", msg);
      });
  }

  function needSdk() {
    if (!board()) return refuse("sdk_required", "Miro Web SDK 2.0 is not loaded (window.miro.board missing)");
    return null;
  }

  function loadSdk(src) {
    return guard(function () {
      if (board()) return ok({ loaded: true, already: true });
      if (typeof document === "undefined") {
        return refuse("sdk_required", "cannot inject the Miro SDK without a document");
      }
      var url = src || SDK_SRC;
      return new Promise(function (resolve) {
        var existing = document.querySelector('script[src="' + url + '"]');
        if (existing) {
          existing.addEventListener("load", function () {
            resolve(board() ? ok({ loaded: true }) : refuse("sdk_required", "Miro SDK script loaded but window.miro.board is missing"));
          });
          existing.addEventListener("error", function () {
            resolve(refuse("sdk_required", "Miro SDK script failed to load"));
          });
          if (board()) resolve(ok({ loaded: true, already: true }));
          return;
        }
        var el = document.createElement("script");
        el.src = url;
        el.async = true;
        el.onload = function () {
          resolve(board() ? ok({ loaded: true }) : refuse("sdk_required", "Miro SDK script loaded but window.miro.board is missing"));
        };
        el.onerror = function () {
          resolve(refuse("sdk_required", "Miro SDK script failed to load from " + url));
        };
        document.head.appendChild(el);
      });
    });
  }

  function sdkCreatePayload(item) {
    var payload = {};
    Object.keys(item).forEach(function (k) {
      if (k === "type" || k === "id" || k === "op") return;
      payload[k] = item[k];
    });
    return payload;
  }

  function applyEffect(effect) {
    return guard(function () {
      var missing = needSdk();
      if (missing) return missing;
      if (!effect || typeof effect !== "object") {
        return refuse("op_required", "applyEffect needs an Effect object");
      }
      var op = String(effect.op || "");
      if (!op) return refuse("op_required", "an Effect needs op:");
      var item = effect.item || {};
      var b = board();

      if (op === "broadcast") {
        return b.events.broadcast(effect.event || "vv-miro", effect.payload).then(function () {
          return ok({ event: effect.event || "vv-miro" });
        });
      }

      if (op === "create") {
        var method = CREATE[item.type];
        if (!method || typeof b[method] !== "function") {
          return refuse("item_type_unsupported", "unknown or unsupported item type " + JSON.stringify(item.type));
        }
        return b[method](sdkCreatePayload(item)).then(function (created) {
          return ok(plainItem(created));
        });
      }

      if (op === "update" || op === "sync") {
        if (blank(item.id)) return refuse("item_id_required", "update/sync needs item.id");
        return b.get({ id: String(item.id) }).then(function (found) {
          var target = Array.isArray(found) ? found[0] : found;
          if (!target) return refuse("item_id_required", "no board item with id " + item.id);
          Object.keys(item).forEach(function (k) {
            if (k === "id" || k === "type") return;
            if (k === "style" && item.style && typeof item.style === "object") {
              target.style = Object.assign({}, target.style || {}, item.style);
              return;
            }
            target[k] = item[k];
          });
          return target.sync().then(function () { return ok(plainItem(target)); });
        });
      }

      if (op === "delete") {
        if (blank(item.id)) return refuse("item_id_required", "delete needs item.id");
        return b.get({ id: String(item.id) }).then(function (found) {
          var target = Array.isArray(found) ? found[0] : found;
          if (!target) return refuse("item_id_required", "no board item with id " + item.id);
          return b.remove(target).then(function () { return ok({ id: String(item.id) }); });
        });
      }

      return refuse("op_unsupported", "unknown Effect op " + JSON.stringify(op));
    });
  }

  function createAppCard(props) {
    var item = Object.assign({ type: "app_card", status: "disconnected" }, props || {});
    return applyEffect({ op: "create", item: item });
  }

  function connectAppCard(appCard, extra) {
    return guard(function () {
      var missing = needSdk();
      if (missing) return missing;
      var card = appCard;
      var ready = Promise.resolve(card);
      if (card && typeof card === "object" && card.id && typeof card.sync !== "function") {
        ready = board().get({ id: String(card.id) }).then(function (found) {
          return Array.isArray(found) ? found[0] : found;
        });
      }
      return ready.then(function (target) {
        if (!target) return refuse("item_id_required", "connectAppCard needs an app card");
        target.status = "connected";
        if (extra) {
          Object.keys(extra).forEach(function (k) { target[k] = extra[k]; });
        }
        return target.sync().then(function () { return ok(plainItem(target)); });
      });
    });
  }

  function svgDataUrl(svg) {
    var raw = String(svg || "");
    if (raw.indexOf("data:image/svg+xml") === 0) return raw;
    var encoded;
    if (typeof btoa === "function") {
      encoded = btoa(unescape(encodeURIComponent(raw)));
    } else if (typeof Buffer !== "undefined") {
      encoded = Buffer.from(raw, "utf8").toString("base64");
    } else {
      throw new Error("no base64 encoder");
    }
    return "data:image/svg+xml;base64," + encoded;
  }

  function uploadSvg(svg, opts) {
    opts = opts || {};
    return applyEffect({
      op: "create",
      item: Object.assign({
        type: "image",
        url: svgDataUrl(svg),
        title: opts.title || "svg"
      }, opts.width ? { width: opts.width } : {}, opts.x != null ? { x: opts.x, y: opts.y || 0 } : {})
    });
  }

  function attr(el, name) {
    if (!el || typeof el.getAttribute !== "function") return "";
    return el.getAttribute(name) || "";
  }

  function num(v, fallback) {
    var n = Number(v);
    return isFinite(n) ? n : fallback;
  }

  function decomposeSvg(svg, opts) {
    opts = opts || {};
    var originX = opts.x || 0;
    var originY = opts.y || 0;
    return guard(function () {
      var missing = needSdk();
      if (missing) return missing;
      if (typeof svg !== "string" || svg.trim() === "") {
        return refuse("svg_required", "decomposeSvg needs an SVG string");
      }
      if (typeof DOMParser === "undefined") {
        return refuse("svg_unsupported", "decomposeSvg needs DOMParser");
      }
      var doc = new DOMParser().parseFromString(svg, "image/svg+xml");
      if (!doc || !doc.documentElement) {
        return refuse("svg_invalid", "could not parse SVG");
      }
      var created = [];
      var nodes = doc.querySelectorAll("rect, circle, ellipse, text, image");
      var chain = Promise.resolve();
      Array.prototype.forEach.call(nodes, function (el) {
        chain = chain.then(function () {
          var tag = el.tagName.toLowerCase();
          var x = originX + num(attr(el, "x") || attr(el, "cx"), 0);
          var y = originY + num(attr(el, "y") || attr(el, "cy"), 0);
          if (tag === "rect") {
            return applyEffect({
              op: "create",
              item: {
                type: "shape",
                shape: "rectangle",
                x: x,
                y: y,
                width: num(attr(el, "width"), 100),
                height: num(attr(el, "height"), 100),
                style: { fillColor: attr(el, "fill") || "#ffffff" }
              }
            }).then(function (r) { if (r.ok) created.push(r.data); });
          }
          if (tag === "circle" || tag === "ellipse") {
            var r = num(attr(el, "r") || attr(el, "rx"), 40);
            return applyEffect({
              op: "create",
              item: {
                type: "shape",
                shape: "circle",
                x: x,
                y: y,
                width: r * 2,
                height: r * 2,
                style: { fillColor: attr(el, "fill") || "#ffffff" }
              }
            }).then(function (res) { if (res.ok) created.push(res.data); });
          }
          if (tag === "text") {
            return applyEffect({
              op: "create",
              item: {
                type: "text",
                content: (el.textContent || "").trim() || " ",
                x: x,
                y: y
              }
            }).then(function (res) { if (res.ok) created.push(res.data); });
          }
          if (tag === "image") {
            var href = attr(el, "href") || attr(el, "xlink:href");
            if (!href) return;
            return applyEffect({
              op: "create",
              item: {
                type: "image",
                url: href,
                x: x,
                y: y,
                width: num(attr(el, "width"), 200)
              }
            }).then(function (res) { if (res.ok) created.push(res.data); });
          }
        });
      });
      return chain.then(function () { return ok(created); });
    });
  }

  function embedUrl(boardId, params) {
    params = params || {};
    if (blank(boardId)) return refuse("board_required", "a Live Embed URL needs a board_id");
    var query = [];
    var autoplay = params.autoplay;
    if (autoplay == null) autoplay = true;
    query.push("autoplay=" + (autoplay ? "true" : "false"));
    if (!blank(params.embedMode || params.embed_mode)) {
      query.push("embedMode=" + encodeURIComponent(params.embedMode || params.embed_mode));
    }
    if (!blank(params.moveToWidget || params.move_to_widget)) {
      query.push("moveToWidget=" + encodeURIComponent(params.moveToWidget || params.move_to_widget));
    }
    var vp = params.moveToViewport || params.move_to_viewport;
    if (vp) {
      if ((params.moveToWidget || params.move_to_widget)) {
        return refuse("viewport_conflict", "a Live Embed URL may set moveToWidget or moveToViewport, not both");
      }
      var value = Array.isArray(vp) ? vp.join(",") : String(vp);
      query.push("moveToViewport=" + encodeURIComponent(value));
    }
    var id = encodeURIComponent(String(boardId));
    return ok(LIVE_EMBED_BASE + "/" + id + "/?" + query.join("&"));
  }

  function embed(host, boardId, params) {
    return guard(function () {
      if (!host || typeof host.appendChild !== "function") {
        return refuse("host_required", "embed needs a DOM host element");
      }
      var built = embedUrl(boardId, params);
      if (!built.ok) return built;
      var iframe = document.createElement("iframe");
      iframe.src = built.data;
      iframe.setAttribute("frameborder", "0");
      iframe.setAttribute("scrolling", "no");
      iframe.setAttribute("allowfullscreen", "true");
      iframe.width = String((params && params.width) || 768);
      iframe.height = String((params && params.height) || 432);
      iframe.setAttribute("data-vv-miro", "embed");
      host.appendChild(iframe);
      state.embedFrame = iframe;
      state.mode = "embed";
      return ok({ src: built.data, iframe: iframe });
    });
  }

  function bindSdkEvents(opts) {
    var b = board();
    if (!b || !b.ui || typeof b.ui.on !== "function") return;

    UI_EVENTS.forEach(function (name) {
      var handler = function (event) {
        var kind = KIND[name] || name;
        var evt = { kind: kind, raw: name };
        if (event && event.items) evt.items = plainItems(event.items);
        if (event && event.appCard) evt.item = plainItem(event.appCard);
        if (event && event.users) evt.users = event.users;
        if (name === "drop" && event) {
          evt.x = event.x;
          evt.y = event.y;
        }
        if (kind === "icon_click" && opts && opts.panelUrl) {
          b.ui.openPanel({ url: opts.panelUrl, height: opts.panelHeight }).catch(function () {});
        }
        if (kind === "app_card_open" && opts && (opts.modalUrl || opts.appCardModalUrl)) {
          var base = opts.appCardModalUrl || opts.modalUrl;
          var url = base;
          if (evt.item && evt.item.id) {
            url += (base.indexOf("?") >= 0 ? "&" : "?") + "appCardId=" + encodeURIComponent(evt.item.id);
          }
          b.ui.openModal({ url: url }).catch(function () {});
        }
        emit(evt);
      };
      state.uiHandlers[name] = handler;
      b.ui.on(name, handler);
    });

    if (b.events && typeof b.events.on === "function") {
      var eventName = (opts && opts.broadcastEvent) || "vv-miro";
      state.broadcastHandler = function (payload) {
        emit({ kind: "broadcast", event: eventName, payload: payload });
      };
      b.events.on(eventName, state.broadcastHandler);
    }
  }

  function unbindSdkEvents() {
    var b = board();
    if (b && b.ui && typeof b.ui.off === "function") {
      Object.keys(state.uiHandlers).forEach(function (name) {
        b.ui.off(name, state.uiHandlers[name]);
      });
    }
    if (b && b.events && typeof b.events.off === "function" && state.broadcastHandler) {
      var eventName = (state.opts && state.opts.broadcastEvent) || "vv-miro";
      b.events.off(eventName, state.broadcastHandler);
    }
    state.uiHandlers = {};
    state.broadcastHandler = null;
  }

  function mount(opts) {
    opts = opts || {};
    return guard(function () {
      var mode = opts.mode || (board() ? "sdk" : (opts.boardId || opts.board_id ? "embed" : "sdk"));
      state.opts = opts;
      if (typeof opts.onEvent === "function") {
        /* also stored on opts; emit() calls it */
      }
      if (mode === "embed") {
        return embed(opts.host, opts.boardId || opts.board_id, opts).then(function (r) {
          if (r.ok) {
            state.mounted = true;
            state.mode = "embed";
          }
          return r;
        });
      }
      function afterSdk() {
        if (!board()) {
          return refuse("sdk_required", "mount({ mode: \"sdk\" }) requires the Miro Web SDK 2.0");
        }
        unbindSdkEvents();
        bindSdkEvents(opts);
        state.mounted = true;
        state.mode = "sdk";
        emit({ kind: "connect", mode: "sdk" });
        return ok({ mode: "sdk" });
      }
      if (board()) return afterSdk();
      return loadSdk(opts.sdkSrc).then(function (r) {
        if (!r.ok) return r;
        return afterSdk();
      });
    });
  }

  function unmount() {
    return guard(function () {
      unbindSdkEvents();
      if (state.embedFrame && state.embedFrame.parentNode) {
        state.embedFrame.parentNode.removeChild(state.embedFrame);
      }
      state.embedFrame = null;
      state.mounted = false;
      state.mode = null;
      state.opts = null;
      return ok({ unmounted: true });
    });
  }

  function on(handler) {
    if (typeof handler !== "function") return refuse("handler_required", "on() needs a function");
    state.handlers.push(handler);
    return ok({ count: state.handlers.length });
  }

  function off(handler) {
    state.handlers = state.handlers.filter(function (fn) { return fn !== handler; });
    return ok({ count: state.handlers.length });
  }

  function broadcast(event, payload) {
    return applyEffect({ op: "broadcast", event: event || "vv-miro", payload: payload });
  }

  function openPanel(options) {
    return guard(function () {
      var missing = needSdk();
      if (missing) return missing;
      return board().ui.openPanel(options || {});
    });
  }

  function openModal(options) {
    return guard(function () {
      var missing = needSdk();
      if (missing) return missing;
      return board().ui.openModal(options || {});
    });
  }

  function info(message) {
    return guard(function () {
      var missing = needSdk();
      if (missing) return missing;
      return board().notifications.showInfo(message);
    });
  }

  function error(message) {
    return guard(function () {
      var missing = needSdk();
      if (missing) return missing;
      return board().notifications.showError(message);
    });
  }

  var VvMiro = {
    VERSION: VERSION,
    SDK_SRC: SDK_SRC,
    LIVE_EMBED_BASE: LIVE_EMBED_BASE,
    ok: ok,
    refuse: refuse,
    context: context,
    loadSdk: loadSdk,
    mount: mount,
    unmount: unmount,
    on: on,
    off: off,
    applyEffect: applyEffect,
    createAppCard: createAppCard,
    connectAppCard: connectAppCard,
    broadcast: broadcast,
    uploadSvg: uploadSvg,
    decomposeSvg: decomposeSvg,
    svgDataUrl: svgDataUrl,
    embedUrl: embedUrl,
    embed: embed,
    openPanel: openPanel,
    openModal: openModal,
    info: info,
    error: error,
    plainItem: plainItem,
    _state: state
  };

  root.VvMiro = VvMiro;
  if (typeof module !== "undefined" && module.exports) module.exports = VvMiro;
})(typeof globalThis !== "undefined" ? globalThis : (typeof window !== "undefined" ? window : this));
