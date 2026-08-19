#!/usr/bin/env python3
"""Gate 1 Part C - MIND -> BACK runtime boundary negative-test.

BACK is now the canonical path: a standard Rails 8 app mounting rails-cpcp, whose
ONLY write surface is the projected CPCP seam at POST /_cpcp/rpc. MIND (this
script, an agent client) may reach an Effect on BACK ONLY through that seam:

  POSITIVE  a valid PUSH (note.create w/ operationId) writes the Effect;
  NEGATIVE  a PUSH without operationId is REFUSED (fail-closed) + NOT written;
  NEGATIVE  a PUSH missing required params is REFUSED + NOT written;
  NEGATIVE  there is no alternate write route (bogus paths / wrong verbs -> 404);
  NEGATIVE  an unknown operation through the seam is rejected, no Effect.

The envelope is rails-cpcp's never-raise shape: {ok:true, result:...} /
{ok:false, error:{reason, because}}.
"""
from __future__ import annotations
import json, os, sys, uuid, urllib.request, urllib.error
from datetime import datetime, timezone

BASE = os.environ.get("BACK_URL", "http://localhost:3000")
checks = []

def check(name, ok, detail=""):
    checks.append({"assertion": name, "ok": bool(ok), "detail": str(detail)[:200]})
    print(("  ok  " if ok else "  FAIL") + f" {name} :: {str(detail)[:160]}")
    return bool(ok)

def req(method, path, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method,
                               headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(r, timeout=15) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

def rpc(method, params=None, op=None):
    body = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}}
    if op is not None:
        body["operationId"] = op
    st, txt = req("POST", "/_cpcp/rpc", body)
    try:
        return st, json.loads(txt)
    except Exception:
        return st, {"_raw": txt}

def titles():
    _st, r = rpc("note.list")
    graph = (((r or {}).get("result") or {}).get("@graph")) or []
    return [n.get("title") for n in graph]

# 0) liveness + the seam advertises its operations
st, txt = req("GET", "/up")
check("back-up", st == 200 and "ok" in txt, f"status={st}")
st, txt = req("GET", "/_cpcp/up")
ops = json.loads(txt).get("operations", []) if st == 200 else []
check("seam-advertises-operations", st == 200 and "note.create" in ops, f"operations={ops}")

# 1) POSITIVE: a valid shaped Effect is written THROUGH the seam
t_ok = f"ok-{uuid.uuid4().hex[:8]}"
_st, r = rpc("note.create", {"title": t_ok, "body": "via seam"}, op=f"op-{uuid.uuid4()}")
check("seam-effect-applied", (r or {}).get("ok") is True and (r.get("result") or {}).get("title") == t_ok, r)
check("effect-visible-in-store", t_ok in titles(), "listed")

# 2) NEGATIVE: PUSH without operationId is REFUSED (fail-closed) and NOT written
t_noop = f"noop-{uuid.uuid4().hex[:8]}"
_st, r = rpc("note.create", {"title": t_noop, "body": "x"})  # no operationId
err = (r or {}).get("error") or {}
check("push-without-opid-refused", (r or {}).get("ok") is False and err.get("reason") == "operation_id_required", r)
check("opid-refused-not-written", t_noop not in titles(), "absent")

# 3) NEGATIVE: PUSH missing required params is REFUSED and NOT written
_st, r = rpc("note.create", {"body": "no title"}, op=f"op-{uuid.uuid4()}")
err = (r or {}).get("error") or {}
check("missing-params-refused", (r or {}).get("ok") is False and err.get("reason") == "missing_params", r)

# 4) NEGATIVE: no alternate write route (bogus path / wrong verb)
st_b, _ = req("POST", "/canonical/write", {"title": "bogus"})
check("no-write-via-bogus-path", st_b == 404, f"POST /canonical/write -> {st_b}")
st_v, _ = req("POST", "/_cpcp/up")
check("no-write-via-wrong-verb", st_v in (404, 405), f"POST /_cpcp/up -> {st_v}")

# 5) NEGATIVE: unknown operation through the seam is rejected, no Effect
t_unk = f"unk-{uuid.uuid4().hex[:8]}"
_st, r = rpc("store.write_direct", {"title": t_unk}, op=f"op-{uuid.uuid4()}")
err = (r or {}).get("error") or {}
check("unknown-operation-rejected", (r or {}).get("ok") is False and err.get("reason") == "unknown_operation", r)
check("unknown-operation-no-effect", t_unk not in titles(), "absent")

ok = all(c["ok"] for c in checks)
report = {
    "gate": "boundary-conformance", "status": "pass" if ok else "fail",
    "subject": os.environ.get("GITHUB_SHA", "LOCAL"),
    "policy": "Part C runtime: MIND reaches an Effect on BACK ONLY via the rails-cpcp /_cpcp seam",
    "started_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "finished_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "tool": "runtimes/mind-pod/test/mind_boundary_test.py",
    "assertions": checks, "digests": {},
}
os.makedirs("evidence", exist_ok=True)
json.dump(report, open("evidence/boundary-runtime.json", "w"), indent=2)
fails = [c["assertion"] for c in checks if not c["ok"]]
if fails:
    print("PART C FAIL: " + ", ".join(fails), file=sys.stderr); sys.exit(1)
print(f"MIND->BACK boundary (Part C): OK ({len(checks)} checks)"); sys.exit(0)
