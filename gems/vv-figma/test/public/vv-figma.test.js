"use strict";

var assert = require("assert");
var path = require("path");
var fs = require("fs");

var created = [];
var pageNodes = [];
var handlers = {};
var uiMessage = null;

function node(type, props) {
  var out = Object.assign({
    id: "id-" + created.length,
    type: type,
    name: type,
    x: 0,
    y: 0,
    width: 100,
    height: 100,
    remove: function () { out.removed = true; }
  }, props);
  out.resize = function (w, h) { out.width = w; out.height = h; };
  created.push(out);
  return out;
}

var fakeFigma = {
  currentPage: {
    appendChild: function (n) { pageNodes.push(n); }
  },
  createRectangle: function () { return node("RECTANGLE"); },
  createEllipse: function () { return node("ELLIPSE"); },
  createText: function () { return node("TEXT", { characters: "" }); },
  createFrame: function () { return node("FRAME"); },
  createLine: function () { return node("LINE"); },
  createStar: function () { return node("STAR"); },
  createPolygon: function () { return node("POLYGON"); },
  getNodeById: function (id) {
    return created.filter(function (n) { return n.id === id; })[0] || null;
  },
  on: function (name, fn) { handlers[name] = fn; },
  off: function (name) { delete handlers[name]; },
  ui: { postMessage: function (m) { uiMessage = m; }, onmessage: null },
  loadFontAsync: function () { return Promise.resolve(); }
};

global.figma = fakeFigma;

var src = fs.readFileSync(path.join(__dirname, "../../public/vv-figma.js"), "utf8");
eval(src);
var VvFigma = global.VvFigma;

function isOk(r, msg) {
  assert.strictEqual(r.ok, true, msg || JSON.stringify(r));
}

function isRefuse(r, reason) {
  assert.strictEqual(r.ok, false, JSON.stringify(r));
  assert.strictEqual(r.reason, reason);
}

async function run() {
  assert.strictEqual(VvFigma.VERSION, "0.1.0");
  assert.strictEqual(VvFigma.context(), "plugin");

  var mounted = await VvFigma.mount({ mode: "plugin" });
  isOk(mounted);
  assert.ok(handlers.selectionchange);
  assert.ok(handlers.documentchange);

  var seen = [];
  VvFigma.on(function (evt) { seen.push(evt.kind); });

  var rect = await VvFigma.applyEffect({
    op: "create",
    item: { type: "rectangle", name: "UC", x: 10, y: 20, width: 220, height: 90 }
  });
  isOk(rect);
  assert.strictEqual(rect.data.name, "UC");
  assert.strictEqual(rect.data.x, 10);
  assert.ok(pageNodes.length >= 1);

  handlers.selectionchange();
  assert.ok(seen.indexOf("select") !== -1);

  var missing = await VvFigma.applyEffect({ op: "create", item: { type: "kanban" } });
  isRefuse(missing, "item_type_unsupported");

  await VvFigma.unmount();
  console.log("vv-figma.js ok");
}

run().catch(function (e) {
  console.error(e);
  process.exit(1);
});
