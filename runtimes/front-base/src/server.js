// Bun FRONT host. Core homepage at /. Overlay may replace / with board.html.
// Proxies /canvas/* to BACK CPCP. Never eval. Never a database.
const ROOT = import.meta.dir;
const OVERRIDE = process.env.FRONT_OVERRIDE || (ROOT + "/overrides");
const BACK = (process.env.BACK_CPCP_ORIGIN || "http://127.0.0.1:3000/_cpcp").replace(/\/$/, "");
const BIND_TOKEN = process.env.FRONT_BIND_TOKEN || "";

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg"
};

function mime(p) {
  const i = p.lastIndexOf(".");
  return MIME[i >= 0 ? p.slice(i) : ""] || "application/octet-stream";
}

function rpcUrl() {
  return BACK.endsWith("/rpc") ? BACK : BACK + "/rpc";
}

const REST = [
  ["POST", "/canvas/blob", "blob.put", "push"],
  ["GET", "/canvas/blob", "blob.get", "pull"],
  ["GET", "/canvas/boards", "board.list", "pull"],
  ["POST", "/canvas/boards/delete", "board.delete", "push"],
  ["POST", "/canvas/boards", "board.put", "push"],
  ["GET", "/canvas/ui/catalog", "ui.catalog.get", "pull"],
  ["POST", "/canvas/ui/surface", "ui.surface.put", "push"],
  ["GET", "/canvas/ui/surface", "ui.surface.get", "pull"],
  ["POST", "/canvas/ui/action", "ui.action", "push"],
  ["GET", "/canvas/front/tree", "front.tree.get", "pull"],
  ["GET", "/canvas/front/path", "front.path.get", "pull"],
  ["POST", "/canvas/front/path", "front.path.act", "push"],
  ["POST", "/canvas/front/bind", "front.bind", "push"],
  ["POST", "/canvas/script/check", "front.script.check", "pull"],
  ["POST", "/canvas/script/run", "front.script.run", "push"]
];

function matchRest(method, path) {
  for (let i = 0; i < REST.length; i++) {
    const row = REST[i];
    if (row[0] === method && (path === row[1] || path.startsWith(row[1] + "?"))) return row;
  }
  return null;
}

async function cpcp(method, params, token) {
  const body = { jsonrpc: "2.0", id: 1, method: method, params: params || {} };
  if (token && !body.params.token) body.params.token = token;
  const r = await fetch(rpcUrl(), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  const json = await r.json();
  if (json && json.error) {
    return { ok: false, reason: json.error.message || "cpcp_error", because: json.error };
  }
  return json.result !== undefined ? json.result : json;
}

async function fileAt(base, path) {
  const f = Bun.file(base + path);
  if (await f.exists()) return f;
  return null;
}

Bun.serve({
  port: Number(process.env.PORT || 3000),
  hostname: process.env.HTTP_BIND || "0.0.0.0",
  async fetch(req) {
    const url = new URL(req.url);
    let path = url.pathname;
    if (path === "/up") return new Response("ok");

    const rest = matchRest(req.method, path);
    if (rest) {
      let params = {};
      url.searchParams.forEach((v, k) => { params[k] = v; });
      if (req.method !== "GET") {
        try { params = Object.assign(params, await req.json()); } catch (_e) { /* empty */ }
      }
      const token = req.headers.get("X-Front-Token") || params.token || "";
      const env = await cpcp(rest[2], params, token);
      const ok = env && env.ok !== false;
      return Response.json(env, { status: ok ? 200 : 502 });
    }

    if (path === "/" || path === "") {
      const overlay = await fileAt(OVERRIDE, "/board.html");
      path = overlay ? "/board.html" : "/core/index.html";
      const f = overlay || (await fileAt(ROOT, path));
      if (f) {
        let html = await f.text();
        html = html.replaceAll("{{FRONT_BIND_TOKEN}}", BIND_TOKEN);
        return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } });
      }
    }

    const fromOverride = await fileAt(OVERRIDE, path);
    if (fromOverride) {
      return new Response(fromOverride, { headers: { "content-type": mime(path) } });
    }
    const fromBase = await fileAt(ROOT, path);
    if (fromBase) {
      return new Response(fromBase, { headers: { "content-type": mime(path) } });
    }
    return new Response("not found", { status: 404 });
  }
});
