// Bun FRONT host. Core homepage at /. Overlay Stage is not here.
const ROOT = import.meta.dir;

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

Bun.serve({
  port: Number(process.env.PORT || 3000),
  async fetch(req) {
    const url = new URL(req.url);
    let path = url.pathname;
    if (path === "/" || path === "") path = "/core/index.html";
    const file = Bun.file(ROOT + path);
    if (await file.exists()) {
      return new Response(file, { headers: { "content-type": mime(path) } });
    }
    return new Response("not found", { status: 404 });
  }
});
