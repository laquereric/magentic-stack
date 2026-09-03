"""MIND -- the pod cognition role, on a SESSION cycle.

  * MIND reads Context BY REFERENCE from BACK (CPCP PULL) and returns an Effect
    *proposal* over the same seam (CPCP PUSH). BACK decides and commits.
  * MIND holds NO provider credential and names no model. Cognition goes to
    SWITCH, which owns sources, keys and routing. Default-deny egress: MIND
    talks only to BACK and SWITCH.
  * MIND never touches GRAPH directly. It asks BACK, which holds the only
    write path -- the boundary Gate 1 Part C exists to enforce.

THE CYCLE IS GROUNDED IN ONE SESSION STATE.

  session.latest   ->  which session is in force (iri, generation)
  session.context  ->  a bounded preview of THAT session graph, by reference
  read_session     ->  a typed proposal, through SWITCH
  session.observe  ->  committed by BACK into the session graph

"The session" is not a thing that exists -- there are states, and they differ.
A reading that cannot say which state it read is a claim about nothing, so the
generation travels through every step into the stored record.

WHY MIND DOES NOT OPEN ITS OWN SESSION BY DEFAULT. One Session entity covers
both actor kinds, so the session MIND reads is normally a human one already in
progress -- that pairing is the point. Opening one unprompted would give MIND a
private room to talk to itself in. MIND_OPEN_SESSION=1 does that deliberately
for a pod with no human in it.
"""
import base64
import hashlib
import json
import os
import time
import urllib.error
import urllib.request

import mind_seam

BACK = os.environ.get("BACK_URL", "http://back:3000")
SWITCH = os.environ.get("SWITCH_URL", "http://switch:8789/v1")
INTERVAL = int(os.environ.get("MIND_INTERVAL", "60"))
NOOA_COMMIT = os.environ.get("NOOA_COMMIT", "8b3c719")
OPEN_OWN = os.environ.get("MIND_OPEN_SESSION", "") == "1"
MODEL = os.environ.get("MIND_MODEL", "openai/switchyard")
PREVIEW = int(os.environ.get("MIND_PREVIEW", "60"))
SEAM_PORT = int(os.environ.get("MIND_SEAM_PORT", "8091"))

# In-memory only: the last reading and admitted cognition requests. A
# restart clears both -- leads, not truth (ROW10_SLICE1).
SEAM_STATE = mind_seam.SeamState()


def rpc(method, params=None, op=None):
    body = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}}
    if op:
        body["operationId"] = op
    req = urllib.request.Request(f"{BACK}/_cpcp/rpc", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    # HTTPError is a 4xx/5xx with a body (the envelope). URLError without a
    # code is infrastructure. Do not catch URLError here -- HTTPError is a
    # subclass and collapsing them loses the far side's reason.
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode())


def unwrap(envelope):
    """CPCP returns a plain object for one result and @graph pairs for a
    collection. Both mean the same thing to a caller; only the shape differs."""
    result = (envelope or {}).get("result") or {}
    graph = result.get("@graph")
    if isinstance(graph, list):
        try:
            return dict(graph)
        except (TypeError, ValueError):
            return {"rows": graph}
    return result


def nooa_version():
    try:
        import nooa
        return getattr(nooa, "__version__", "unknown")
    except Exception as e:  # noqa: BLE001
        return f"unavailable ({e.__class__.__name__})"


def ground():
    """Which session is in force. Everything downstream quotes this."""
    state = unwrap(rpc("session.latest"))
    if state.get("ok"):
        return state, None
    if not OPEN_OWN:
        return None, state
    # Deliberate, opt-in: a pod with no human in it still has something to read.
    opened = unwrap(rpc("session.open", {"actor_kind": "agent"},
                        op="mind-open-" + hashlib.sha256(BACK.encode()).hexdigest()[:16]))
    return (opened, None) if opened.get("ok") else (None, opened)


def preview(session_id):
    """A bounded look at THAT session graph -- by reference, never the store.

    Scoped by BACK to GRAPH <urn:mm:session:ID>. The store is append-only and
    holds every session ever opened, so an unscoped read would cross sessions
    and return rows that look plausible while belonging to someone else.
    """
    ctx = unwrap(rpc("session.context", {"session_id": session_id, "limit": PREVIEW}))
    if not ctx.get("ok"):
        return [], ctx
    return ctx.get("rows") or [], None


def cognition(session_iri, generation, rows):
    import asyncio
    from nooa.unifiedllm import CompletionClient
    from mind_agent import build_agent
    # No key: SWITCH is pod-internal and never published. Credentials live there.
    llm = CompletionClient(model=MODEL, api_key="switchyard-local", api_base=SWITCH)
    return asyncio.run(build_agent(llm).read_session(session_iri, generation, rows))


def propose(reading, state):
    """A CPCP-grounded action: an operation the seam already admits, carrying an
    operationId derived from the session state it read.

    Idempotent by construction -- one reading per (session, generation). Re-reading
    an unchanged session returns the cached receipt rather than a second opinion.
    """
    ground_key = "%s@%s" % (state["session_iri"], state["generation"])
    op = "mind-reading-" + hashlib.sha256(ground_key.encode()).hexdigest()[:16]
    params = {
        "operationId": op,
        "session_id": state["session_id"],
        "title": reading.title,
        "body": reading.body,
    }
    return unwrap(rpc("session.observe", params, op=op)), op


def observe(reading, receipt, op, state, rows):
    obs = {"nooa": {"version": nooa_version(), "commit": NOOA_COMMIT},
           "grounded_in": {"session": state["session_iri"], "generation": state["generation"]},
           "operationId": op,
           "proposed": {"title": reading.title, "previewed": len(rows)},
           "committed_by_back": bool(receipt.get("ok")),
           "stored_in": receipt.get("graph")}
    print(json.dumps({"mind_observation": obs}), flush=True)  # bounded projection -- NOT durable truth
    mind_seam.note_reading(SEAM_STATE, obs)


def cycle():
    req = mind_seam.take_request(SEAM_STATE)
    if req is not None:
        # An admitted cognition request runs ahead of the BACK poll, one per
        # cycle. Proposing stays poll-shaped: the receipt still comes from BACK.
        state = {"session_iri": req["session_iri"], "generation": req["generation"],
                 "session_id": req["session_id"]}
        reading = cognition(req["session_iri"], req["generation"], req["rows"])
        receipt, op = propose(reading, state)
        observe(reading, receipt, op, state, req["rows"])
        return

    state, refusal = ground()
    if refusal is not None:
        # No open session is not an error. It is the ordinary state of a pod
        # nobody is using yet, and MIND waits rather than inventing one.
        print(json.dumps({"mind_waiting": refusal}), flush=True)
        return

    rows, refused = preview(state["session_id"])
    if refused is not None:
        print(json.dumps({"mind_waiting": refused}), flush=True)
        return

    reading = cognition(state["session_iri"], state["generation"], rows)
    receipt, op = propose(reading, state)
    observe(reading, receipt, op, state, rows)


def main():
    print(json.dumps({"mind_boot": {"back": BACK, "switch": SWITCH, "open_own_session": OPEN_OWN,
                                    "nooa_commit": NOOA_COMMIT,
                                    "nooa_version": nooa_version(),
                                    "egress": "default-deny"}}), flush=True)
    try:
        mind_seam.start(SEAM_STATE, SEAM_PORT)
        print(json.dumps({"mind_seam_boot": {"port": SEAM_PORT, "published": False}}), flush=True)
    except Exception as e:  # noqa: BLE001
        # The cycle must not depend on seam configuration: an unbindable
        # seam logs loudly and cognition continues client-only.
        print(json.dumps({"mind_seam_error": f"{e.__class__.__name__}: {e}"}), flush=True)
    while True:
        try:
            cycle()
        except Exception as e:  # noqa: BLE001
            print(json.dumps({"mind_error": f"{e.__class__.__name__}: {e}"}), flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
