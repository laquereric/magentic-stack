"""The MIND Harness: the ONLY seam around the NOOA runtime.

Guardrails (see docs/PRELIMINARY_DESIGN.md, section 1):
  * MIND holds NO database credential and NO direct GRAPH access.
  * MIND reads Context by reference from BACK (CPCP PULL) and returns an Effect
    *proposal* over the same seam (CPCP PUSH). BACK decides and commits.
  * Default-deny egress: MIND talks only to BACK_URL and, if a key is configured,
    the one provider api_base. No other network egress.
  * Every cycle records the NOOA release identity so behavior is traceable.

This POC drives cognition on a pull cadence; the target is a BACK-initiated
MagenticMindOperation over the same fixed CID contract.
"""
import os, json, time, hashlib, urllib.request

BACK = os.environ.get("BACK_URL", "http://back:3000")
MODEL = os.environ.get("MIND_MODEL", "")
API_KEY = os.environ.get("MIND_API_KEY", "")
API_BASE = os.environ.get("MIND_API_BASE", "")
INTERVAL = int(os.environ.get("MIND_INTERVAL", "12"))
NOOA_COMMIT = os.environ.get("NOOA_COMMIT", "8b3c719")  # pinned upstreams/nooa/src


def rpc(method, params=None, op=None):
    body = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}}
    if op:
        body["operationId"] = op
    req = urllib.request.Request(f"{BACK}/_cpcp/rpc", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read().decode())


def pull_notes():
    return ((rpc("note.list").get("result") or {}).get("@graph")) or []


def nooa_version():
    try:
        import nooa
        return getattr(nooa, "__version__", "unknown")
    except Exception as e:  # noqa: BLE001
        return f"unavailable ({e.__class__.__name__})"


def cognition(notes):
    if API_KEY and MODEL:  # LLM path only when a provider is explicitly configured
        import asyncio
        from nooa.unifiedllm import CompletionClient
        from mind_agent import build_agent
        llm = CompletionClient(model=MODEL, api_key=API_KEY, api_base=API_BASE or None)
        return asyncio.run(build_agent(llm).summarize(notes)), "nooa-llm"
    from mind_agent import deterministic_insight
    return deterministic_insight(notes), "deterministic"


def propose(insight):
    # Idempotent by construction: identical Context -> same operationId -> BACK
    # returns the cached receipt (Profile 2/4), so MIND never double-writes.
    key = hashlib.sha256((insight.title + "\x1f" + insight.body).encode()).hexdigest()[:16]
    op = f"mind-{key}"
    return rpc("note.create", {"title": insight.title, "body": insight.body}, op=op), op


def cycle():
    notes = [n for n in pull_notes() if n.get("title") != "MIND insight"]  # skip our own output
    insight, mode = cognition(notes)
    receipt, op = propose(insight)
    print(json.dumps({"mind_observation": {  # bounded projection -- NOT durable truth
        "nooa": {"version": nooa_version(), "commit": NOOA_COMMIT},
        "cognition_mode": mode, "operationId": op,
        "proposed": {"title": insight.title, "note_count": insight.note_count},
        "committed_by_back": bool((receipt or {}).get("ok")),
    }}), flush=True)


def main():
    print(json.dumps({"mind_boot": {"back": BACK, "nooa_commit": NOOA_COMMIT,
                                    "nooa_version": nooa_version(), "egress": "default-deny"}}), flush=True)
    while True:
        try:
            cycle()
        except Exception as e:  # noqa: BLE001
            print(json.dumps({"mind_error": f"{e.__class__.__name__}: {e}"}), flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
