#!/usr/bin/env python3
"""rails-cpcp reference FRONT pod.

The MANDATORY, distinct FRONT half of a two-pod CPCP deployment. It is a thin,
no-Rails process that reads the BACK's CID and exercises the JSON-RPC-LD
PULL/PUSH boundary over the wire (never in-process). Long-running HTTP server:
  GET /         -> runs the CID-driven PULL->GET->PUSH linkage, returns JSON
  GET /healthz  -> liveness
Set RUN_ONCE=1 to run the linkage once and exit (demo/CI).
"""
import json, os, sys, uuid, urllib.error, urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

BACK = os.environ.get("BACK_URL", "http://back:80").rstrip("/")
VOCAB = "https://w3id.org/laquereric/cpcp/ns#"


def _post(method, params=None, operation_id=None):
    body = {"jsonrpc": "2.0", "@context": {"@vocab": VOCAB}, "id": 1,
            "method": method, "params": params or {}}
    if operation_id:
        body["operationId"] = operation_id
    req = urllib.request.Request(BACK + "/_cpcp/rpc", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    try:
        return json.loads(urllib.request.urlopen(req, timeout=15).read())
    except urllib.error.HTTPError as e:
        return json.loads(e.read())


def _cid():
    try:
        return json.loads(urllib.request.urlopen(BACK + "/_cpcp/cid.json", timeout=15).read())
    except urllib.error.HTTPError as e:
        return json.loads(e.read())


def run_linkage():
    cid = _cid()
    ops = cid.get("operations", [])
    pulls = [o for o in ops if o.get("direction") == "PULL"]
    list_op = next((o for o in pulls if o["result"]["shape"] == "Collection"), None)
    get_op = next((o for o in pulls if o["result"]["shape"] == "Record" and o.get("params")), None)
    steps = []
    if not list_op:
        raise RuntimeError("no PULL collection operation in CID")

    r = _post(list_op["name"])
    if not r.get("ok"):
        raise RuntimeError(f"PULL {list_op['name']} failed: {r}")
    graph = r["result"].get("@graph", [])
    steps.append(f"PULL {list_op['name']} -> {len(graph)} records")

    linked = None
    if get_op and graph:
        idv = graph[0].get("@id") or graph[0].get("id")
        pname = get_op["params"][0]
        r2 = _post(get_op["name"], {pname: idv})
        if not r2.get("ok"):
            raise RuntimeError(f"GET {get_op['name']} failed: {r2}")
        linked = r2["result"]
        steps.append(f"GET {get_op['name']}({idv}) -> @id {linked.get('@id') or linked.get('id')}")

    pushed = None
    push_method = os.environ.get("CPCP_PUSH_METHOD")
    if push_method:
        params = json.loads(os.environ.get("CPCP_PUSH_PARAMS", "{}"))
        opid = str(uuid.uuid4())
        r3 = _post(push_method, params, operation_id=opid)
        if not r3.get("ok"):
            raise RuntimeError(f"PUSH {push_method} failed: {r3}")
        pushed = {"operationId": opid, "result": r3["result"]}
        steps.append(f"PUSH {push_method} operationId={opid} ok")

    verified = "PULL->GET->PUSH @id linkage verified" if (linked and pushed) else \
               ("PULL->GET @id linkage verified" if linked else "PULL verified")
    return {"ok": True, "back": BACK, "cid_id": cid.get("@id"), "steps": steps,
            "linked": linked, "pushed": pushed, "verified": verified}


class Handler(BaseHTTPRequestHandler):
    def _send(self, obj, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(obj).encode())

    def do_GET(self):
        if self.path.startswith("/healthz"):
            return self._send({"ok": True})
        try:
            self._send(run_linkage())
        except Exception as e:  # never raise across the boundary
            self._send({"ok": False, "error": str(e)}, 502)

    def log_message(self, *args):
        pass


def main():
    if os.environ.get("RUN_ONCE"):
        out = run_linkage()
        print("\n".join(out["steps"]))
        print("OK: " + out["verified"])
        return 0
    port = int(os.environ.get("PORT", "8080"))
    print(f"rails-cpcp FRONT pod on :{port} -> BACK {BACK}", flush=True)
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    sys.exit(main() or 0)
