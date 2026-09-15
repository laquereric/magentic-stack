"use strict";

var assert = require("assert");
var path = require("path");
var fs = require("fs");

var created = [];
var uiListeners = {};
var eventListeners = {};
var removed = [];
var notifications = [];

function item(type, props) {
  var out = Object.assign({ id: "id-" + created.length, type: type }, props);
  out.sync = function () { return Promise.resolve(); };
  return out;
}

var fakeBoard = {
  createAppCard: function (p) { var i = item("app_card", p); created.push(i); return Promise.resolve(i); },
  createStickyNote: function (p) { var i = item("sticky_note", p); created.push(i); return Promise.resolve(i); },
  createShape: function (p) { var i = item("shape", p); created.push(i); return Promise.resolve(i); },
  createText: function (p) { var i = item("text", p); created.push(i); return Promise.resolve(i); },
  createFrame: function (p) { var i = item("frame", p); created.push(i); return Promise.resolve(i); },
  createConnector: function (p) { var i = item("connector", p); created.push(i); return Promise.resolve(i); },
  createImage: function (p) { var i = item("image", p); created.push(i); return Promise.resolve(i); },
  createCard: function (p) { var i = item("card", p); created.push(i); return Promise.resolve(i); },
  createEmbed: function (p) { var i = item("embed", p); created.push(i); return Promise.resolve(i); },
  createTag: function (p) { var i = item("tag", p); created.push(i); return Promise.resolve(i); },
  get: function (q) {
    var found = created.filter(function (i) { return !q || !q.id || i.id === q.id; });
    return Promise.resolve(found);
  },
  remove: function (i) { removed.push(i.id); return Promise.resolve(); },
  ui: {
    on: function (name, fn) { uiListeners[name] = fn; },
    off: function (name) { delete uiListeners[name]; },
    openPanel: function (opts) { return Promise.resolve({ waitForClose: function () { return Promise.resolve(); }, opts: opts }); },
    openModal: function (opts) { return Promise.resolve({ waitForClose: function () { return Promise.resolve(); }, opts: opts }); }
  },
  events: {
    broadcast: function (name, payload) { return Promise.resolve({ name: name, payload: payload }); },
    on: function (name, fn) { eventListeners[name] = fn; return Promise.resolve(); },
    off: function (name) { delete eventListeners[name]; return Promise.resolve(); }
  },
  notifications: {
    showInfo: function (m) { notifications.push(["info", m]); return Promise.resolve(); },
    showError: function (m) { notifications.push(["error", m]); return Promise.resolve(); }
  }
};

global.miro = { board: fakeBoard };

var src = fs.readFileSync(path.join(__dirname, "../../public/vv-miro.js"), "utf8");
eval(src);
var VvMiro = global.VvMiro;

function isOk(r, msg) {
  assert.strictEqual(r.ok, true, msg || JSON.stringify(r));
}

function isRefuse(r, reason) {
  assert.strictEqual(r.ok, false, JSON.stringify(r));
  assert.strictEqual(r.reason, reason);
}

async function run() {
  assert.strictEqual(VvMiro.VERSION, "0.1.0");
  assert.strictEqual(VvMiro.context(), "sdk");

  var mounted = await VvMiro.mount({ mode: "sdk" });
  isOk(mounted);
  assert.ok(uiListeners["selection:update"]);
  assert.ok(uiListeners["app_card:open"]);
  assert.ok(uiListeners["items:create"]);

  var seen = [];
  VvMiro.on(function (evt) { seen.push(evt.kind); });

  var card = await VvMiro.createAppCard({ title: "CPCP call", status: "disconnected" });
  isOk(card);
  assert.strictEqual(card.data.type, "app_card");
  assert.strictEqual(card.data.title, "CPCP call");
  assert.strictEqual(typeof card.data.sync, "undefined", "plainItem must strip SDK methods");

  var sticky = await VvMiro.applyEffect({
    op: "create",
    item: { type: "sticky_note", content: "hello", x: 10, y: 20 }
  });
  isOk(sticky);
  assert.strictEqual(sticky.data.content, "hello");

  var updated = await VvMiro.applyEffect({
    op: "update",
    item: { id: sticky.data.id, content: "updated" }
  });
  isOk(updated);

  var del = await VvMiro.applyEffect({
    op: "delete",
    item: { id: sticky.data.id }
  });
  isOk(del);
  assert.ok(removed.indexOf(sticky.data.id) >= 0);

  var badOp = await VvMiro.applyEffect({ op: "explode", item: { type: "shape" } });
  isRefuse(badOp, "op_unsupported");

  var badType = await VvMiro.applyEffect({ op: "create", item: { type: "kanban" } });
  isRefuse(badType, "item_type_unsupported");

  var missingId = await VvMiro.applyEffect({ op: "delete", item: { type: "shape" } });
  isRefuse(missingId, "item_id_required");

  uiListeners["selection:update"]({ items: [created[0]] });
  assert.ok(seen.indexOf("select") >= 0);

  uiListeners["app_card:open"]({ appCard: created[0] });
  assert.ok(seen.indexOf("app_card_open") >= 0);

  var svg = await VvMiro.uploadSvg("<svg xmlns='http://www.w3.org/2000/svg'></svg>", { title: "g" });
  isOk(svg);
  assert.ok(String(svg.data.url).indexOf("data:image/svg+xml;base64,") === 0);

  var url = VvMiro.embedUrl("o9J_abc=", { autoplay: true, embedMode: "view_only_without_ui" });
  isOk(url);
  assert.ok(url.data.indexOf("https://miro.com/app/live-embed/o9J_abc%3D/") === 0);
  assert.ok(url.data.indexOf("autoplay=true") >= 0);
  assert.ok(url.data.indexOf("embedMode=view_only_without_ui") >= 0);

  var conflict = VvMiro.embedUrl("board", { moveToWidget: "1", moveToViewport: "0,0,1,1" });
  isRefuse(conflict, "viewport_conflict");

  var noBoard = VvMiro.embedUrl("");
  isRefuse(noBoard, "board_required");

  var bc = await VvMiro.broadcast("vv-miro", { effect: "x" });
  isOk(bc);

  var connected = await VvMiro.connectAppCard(card.data);
  isOk(connected);
  assert.strictEqual(connected.data.status, "connected");

  var unmounted = await VvMiro.unmount();
  isOk(unmounted);

  global.miro = undefined;
  delete require.cache[require.resolve("assert")];
  var VvMiro2;
  (function () {
    var root = global;
    eval(src);
    VvMiro2 = root.VvMiro;
  })();
  var noSdk = await VvMiro2.applyEffect({ op: "create", item: { type: "sticky_note", content: "x" } });
  isRefuse(noSdk, "sdk_required");
  assert.strictEqual(VvMiro2.context(), "none");

  console.log("vv-miro.js: " + "ok");
}

run().catch(function (e) {
  console.error(e);
  process.exit(1);
});
