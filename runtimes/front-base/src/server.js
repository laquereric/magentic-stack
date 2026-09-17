// Bun FRONT host. Core homepage at / unless overlay.html is present.
// Overlay Stage is copied onto this image (P4). CPCP grant is BACK.
const ROOT = import.meta.dir;
const OVERLAY = ROOT + "/overlay.html";
// An overlay image may mount a directory of its own files (FRONT_OVERRIDE).
// It may supply static assets and, via hooks.js, additional proxy routes.
// front-base stays product-agnostic: it never names an overlay's routes.
const OVERRIDE = (process.env.FRONT_OVERRIDE || "").replace(/\/$/, "");

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".svg": "image/svg+xml"
};

function mime(p) {
  const i = p.lastIndexOf(".");
  return MIME[i >= 0 ? p.slice(i) : ""] || "application/octet-stream";
}

function backOrigin() {
  return (process.env.BACK_CPCP_ORIGIN || "").replace(/\/$/, "");
}

async function cpcp(method, params, opts = {}) {
  const origin = backOrigin();
  if (!origin) {
    return { ok: false, reason: "back_origin_missing", because: { message: "BACK_CPCP_ORIGIN unset" } };
  }
  const id = crypto.randomUUID();
  const body = {
    jsonrpc: "2.0",
    id,
    method,
    params: params || {}
  };
  if (opts.push) {
    body.operationId = opts.operationId || (params && params.operationId);
  }
  const headers = { "content-type": "application/json" };
  if (opts.token) headers["X-Front-Token"] = opts.token;
  const res = await fetch(origin + "/rpc", { method: "POST", headers, body: JSON.stringify(body) });
  return res.json();
}

function tokenOf(req) {
  return req.headers.get("x-front-token") || "";
}

async function readJson(req) {
  const t = await req.text();
  if (!t) return {};
  try { return JSON.parse(t); } catch { return {}; }
}

const PUSH = {
  "POST /canvas/blob": { rpc: "blob.put", push: true },
  "POST /canvas/boards": { rpc: "board.put", push: true },
  "POST /canvas/boards/delete": { rpc: "board.delete", push: true },
  "POST /canvas/ui/surface": { rpc: "ui.surface.put", push: true },
  "POST /canvas/ui/action": { rpc: "ui.action", push: true },
  "POST /canvas/front/path": { rpc: "front.path.act", push: true },
  "POST /canvas/front/bind": { rpc: "front.bind", push: true },
  "POST /canvas/script/check": { rpc: "front.script.check", push: false },
  "POST /canvas/script/run": { rpc: "front.script.run", push: true }
};

const PULL = {
  "GET /canvas/blob": { rpc: "blob.get", keys: ["digest"] },
  "GET /canvas/boards": { rpc: "board.list", keys: [] },
  "GET /canvas/ui/catalog": { rpc: "ui.catalog.get", keys: [] },
  "GET /canvas/ui/surface": { rpc: "ui.surface.get", keys: ["aciaCid", "digest", "as"] },
  "GET /canvas/front/tree": { rpc: "front.tree.get", keys: ["blobDigest"] },
  "GET /canvas/front/path": { rpc: "front.path.get", keys: ["path", "blobDigest"] }
};

async function loadOverlayHooks() {
  if (!OVERRIDE) return;
  const p = OVERRIDE + "/hooks.js";
  if (!(await Bun.file(p).exists())) return;
  try {
    const h = await import("file://" + p);
    Object.assign(PUSH, h.PUSH || {});
    Object.assign(PULL, h.PULL || {});
  } catch (_e) { /* overlay hooks are optional; a broken one must not down FRONT */ }
}
await loadOverlayHooks();

async function proxy(req, url) {
  const key = req.method + " " + url.pathname;
  const tok = tokenOf(req);
  if (PUSH[key]) {
    const spec = PUSH[key];
    const params = await readJson(req);
    if (tok && !params.token) params.token = tok;
    return Response.json(await cpcp(spec.rpc, params, {
      push: spec.push,
      operationId: params.operationId,
      token: tok
    }));
  }
  if (PULL[key]) {
    const spec = PULL[key];
    const params = {};
    for (const k of spec.keys) {
      const v = url.searchParams.get(k);
      if (v) params[k] = v;
    }
    if (tok) params.token = tok;
    return Response.json(await cpcp(spec.rpc, params, { token: tok }));
  }
  return null;
}

function withToken(html) {
  return html.replaceAll("{{FRONT_BIND_TOKEN}}", process.env.FRONT_BIND_TOKEN || "");
}

async function overlayHtml() {
  const f = Bun.file(OVERLAY);
  if (!(await f.exists())) return null;
  return withToken(await f.text());
}

Bun.serve({
  port: Number(process.env.PORT || 3000),
  async fetch(req) {
    const url = new URL(req.url);
    const proxied = await proxy(req, url);
    if (proxied) return proxied;

    let path = url.pathname;
    if (path === "/" || path === "") {
      const over = await overlayHtml();
      if (over) {
        return new Response(over, { headers: { "content-type": "text/html; charset=utf-8" } });
      }
      path = "/core/index.html";
    }
    let file = OVERRIDE ? Bun.file(OVERRIDE + path) : null;
    if (!file || !(await file.exists())) file = Bun.file(ROOT + path);
    if (await file.exists()) {
      if (path.endsWith(".html")) {
        return new Response(withToken(await file.text()), {
          headers: { "content-type": mime(path) }
        });
      }
      return new Response(file, { headers: { "content-type": mime(path) } });
    }
    return new Response("not found", { status: 404 });
  }
});
