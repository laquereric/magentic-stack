#!/usr/bin/env python3
"""Cross-seam envelope conformance: BACK and MIND discipline, one battery.

Row 10 slice 3. This asserts SHARED DISCIPLINE, not method parity -- the
seams serve different methods by design. What both must hold: every
response is an envelope ({ok, jsonrpc, id}), refusals name a reason from
each seam's documented taxonomy, and each seam keeps its own status
profile (BACK: always HTTP 200 per row 49; MIND: status per refusal per
row 49 KEEP BOTH).

Usage (against a live pod; no production data touched):
    BACK_URL=http://back:3000 MIND_URL=http://mind:8091 \\
        MIND_TOKEN=<MIND_CALLERS token> python3 tooling/cpcp/conformance_seams.py

All three env vars are required; missing any is a fail, not a skip.
CI wiring (boundary-conformance.yml Gate 1) is a follow-up; this runner
is the suite both seams must pass.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

BACK = os.environ.get("BACK_URL", "")
MIND = os.environ.get("MIND_URL", "")
TOKEN = os.environ.get("MIND_TOKEN", "")


def post(base, body, raw=None, token=None):
    data = raw if raw is not None else json.dumps(body).encode()
    req = urllib.request.Request(
        base + "/_cpcp/rpc", data=data,
        headers={"Content-Type": "application/json",
                 **({"Authorization": "Bearer " + token} if token else {})},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())


def check(name, cond, detail=""):
    print("%s %s %s" % ("PASS" if cond else "FAIL", name, detail))
    return cond


def main():
    missing = [k for k, v in (("BACK_URL", BACK), ("MIND_URL", MIND), ("MIND_TOKEN", TOKEN)) if not v]
    if missing:
        print("FAIL: missing env (not a skip): %s" % ",".join(missing), file=sys.stderr)
        return 1
    ok = True

    def rpc(seam, method, params=None, token=None, raw=None, rid=1):
        base = BACK if seam == "back" else MIND
        body = {"jsonrpc": "2.0", "id": rid, "method": method, "params": params or {}}
        tok = token if seam == "mind" else None
        return post(base, body, raw=raw, token=tok)

    def reason(env, seam):
        # BACK nests refusals under error (rails-cpcp envelope); the
        # hand-rolled seams carry reason flat. Both documented, both stable.
        if seam == "back":
            return (env.get("error") or {}).get("reason")
        return env.get("reason")

    # 1. Unknown methods refuse with the documented reason on both seams.
    st, env = rpc("back", "nope.nope")
    ok &= check("back unknown", st == 200 and reason(env, "back") == "unknown_operation"
                and env.get("ok") is False, "status=%s" % st)
    st, env = rpc("mind", "nope.nope", token=TOKEN)
    ok &= check("mind unknown", st == 400 and reason(env, "mind") == "unknown_operation", "status=%s" % st)

    # 2. Empty bodies refuse on both seams. BACK collapses all parse
    # failures to unknown_operation (measured, stable); MIND names them.
    st, env = rpc("back", "note.list", raw=b"")
    ok &= check("back empty", st == 200 and reason(env, "back") == "unknown_operation", "status=%s" % st)
    st, env = rpc("mind", "mind.up", raw=b"", token=TOKEN)
    ok &= check("mind empty", st == 400 and reason(env, "mind") == "unparseable_json", "status=%s" % st)

    # 3. Garbage bodies refuse on both seams.
    st, env = rpc("back", "note.list", raw=b"{oops")
    ok &= check("back garbage", st == 200 and reason(env, "back") == "unknown_operation", "status=%s" % st)
    st, env = rpc("mind", "mind.up", raw=b"{oops", token=TOKEN)
    ok &= check("mind garbage", st == 400 and reason(env, "mind") == "unparseable_json", "status=%s" % st)

    # 4. Every envelope carries ok/jsonrpc/id, and the id echoes.
    st, env = rpc("back", "note.list", rid=99)
    ok &= check("back envelope", st == 200 and env.get("ok") is True
                and env.get("jsonrpc") == "2.0" and env.get("id") == 99, "status=%s" % st)
    st, env = rpc("mind", "mind.up", token=TOKEN, rid=99)
    ok &= check("mind envelope", st == 200 and env.get("ok") is True
                and env.get("result", {}).get("ready") is True
                and env.get("jsonrpc") == "2.0" and env.get("id") == 99, "status=%s" % st)

    # 5. MIND auth discipline (BACK has no callers by design).
    st, env = rpc("mind", "mind.up", token="")
    ok &= check("mind no-token", st == 401 and env.get("reason") == "mind_unauthenticated", "status=%s" % st)
    st, env = rpc("mind", "mind.reading.latest", token=TOKEN)
    ok &= check("mind latest", st == 200 and "recorded" in env.get("result", {}), "status=%s" % st)

    print("conformance: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
