#!/usr/bin/env python3
"""Gate 1 Part C - MIND -> BACK runtime boundary negative-test.

MIND (this script, an agent client) may reach an Effect on BACK ONLY through the
shape-gated JSON-RPC-LD seam (POST /rpc). Proven against a running BACK:

  POSITIVE  a valid shaped row.push writes the Effect (via the seam);
  NEGATIVE  a shape-violating row.push is REFUSED (fail-closed) and NOT written;
  NEGATIVE  there is no alternate write route (bogus paths / wrong verbs -> 404);
  NEGATIVE  an unknown method through the seam is rejected (-32601), no Effect.

Canonical target: the BACK here is the POC's hand-rolled seam; the production path
is a standard Rails 8 app + rails_cpcp (BACK) with FRONT + BACKJOB. The boundary
property under test is identical: Effects only via the seam.
"""
from __future__ import annotations
import json, os, sys, urllib.request, urllib.error
from datetime import datetime, timezone

BASE = os.environ.get("BACK_URL", "http://localhost:3000")
TABLE = "https://osi8.poc/table/sales-pivot"
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
        body["params"]["operationId"] = op
    st, txt = req("POST", "/rpc", body)
    try:
        return st, json.loads(txt)
    except Exception:
        return st, {"_raw": txt}

def valid_row(month):
    return {"@type": "Row", "table": TABLE, "month": month,
            "y2021": 100, "y2022": 110, "y2023": 120, "y2024": 130, "y2025": 140,
            "pct_change": 1.05}

def table_months():
    _st, r = rpc("canonical.get", {"id": TABLE})
    rows = (((r or {}).get("result") or {}).get("record") or {}).get("rows") or []
    return [row.get("month") for row in rows]

# 0) liveness + manifest advertises the seam
st, txt = req("GET", "/up")
check("back-up", st == 200 and "ok" in txt, f"status={st}")
st, txt = req("GET", "/manifest")
names = [m.get("name") for m in (json.loads(txt).get("methods", []) if st == 200 else [])]
check("manifest-advertises-seam", st == 200 and "row.push" in names, f"methods={names}")

# 1) POSITIVE: a valid shaped Effect is written THROUGH the seam
_st, r = rpc("row.push", {"row": valid_row("Mar")}, op="op-ci-valid-1")
res = (r or {}).get("result") or {}
check("seam-effect-applied", res.get("ok") is True and "receipt" in res, res)
check("effect-visible-in-store", "Mar" in table_months(), table_months())

# 2) NEGATIVE: shape violation is REFUSED (fail-closed) and NOT written
_st, r = rpc("row.push", {"row": {**valid_row("Apr"), "evil": "x"}}, op="op-ci-bad-1")
res = (r or {}).get("result") or {}
check("shape-violation-refused", res.get("ok") is False and res.get("reason") == "shape_violation", res)
check("refused-effect-not-written", "Apr" not in table_months(), table_months())

# 3) NEGATIVE: no alternate write route (wrong verb / bogus paths -> 404)
st_v, _ = req("POST", "/manifest")
check("no-write-via-wrong-verb", st_v in (404, 405), f"POST /manifest -> {st_v}")
st_b, _ = req("POST", "/canonical/write", {"month": "May"})
check("no-write-via-bogus-path", st_b == 404, f"POST /canonical/write -> {st_b}")
check("bogus-path-no-effect", "May" not in table_months(), table_months())

# 4) NEGATIVE: unknown method through the seam is rejected, no Effect
_st, r = rpc("store.write_direct", {"row": valid_row("Jun")}, op="op-ci-unknown-1")
err = (r or {}).get("error") or {}
check("unknown-method-rejected", err.get("code") == -32601, r)
check("unknown-method-no-effect", "Jun" not in table_months(), table_months())

ok = all(c["ok"] for c in checks)
report = {
    "gate": "boundary-conformance", "status": "pass" if ok else "fail",
    "subject": os.environ.get("GITHUB_SHA", "LOCAL"),
    "policy": "Part C runtime: MIND reaches an Effect on BACK ONLY via the shape-gated /_cpcp seam",
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
