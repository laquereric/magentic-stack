"""MIND -- the pod's cognition role, on a BOARD cycle.

  * MIND reads Context BY REFERENCE from BACK (CPCP PULL) and returns an Effect
    *proposal* over the same seam (CPCP PUSH). BACK decides and commits.
  * MIND holds NO provider credential and names no model. Cognition goes to
    SWITCH, which owns sources, keys and routing. Default-deny egress: MIND
    talks only to BACK and SWITCH.

THE CYCLE IS GROUNDED IN ONE BOARD STATE.

  acia.latest  ->  which state is in force (surface, document IRI, digest)
  graph.query  ->  a bounded preview of THAT document, by reference
  read_board   ->  a typed proposal, through SWITCH
  blob.put     ->  stored by BACK, citing the digest it was read from

"The board" is not a thing that exists -- there are states, and they differ. A
reading that cannot say which state it read is a claim about nothing, so the
digest travels through every step into the stored account.

WHY THE READING IS NOT A FRAME. blob.put takes a content type, and typing this
as ...translation.frame would put MIND's output ON the board -- which changes
the board, which changes the digest, which asks MIND to read it again, forever.
The reading is its own kind and ComposedFrames does not collect it.
"""
import base64
import hashlib
import json
import os
import time
import urllib.request

BACK = os.environ.get("BACK_URL", "http://back:3000")
SWITCH = os.environ.get("SWITCH_URL", "http://switch:8789/v1")
INTERVAL = int(os.environ.get("MIND_INTERVAL", "60"))
NOOA_COMMIT = os.environ.get("NOOA_COMMIT", "8b3c719")
SLUG = os.environ.get("MIND_SLUG", "board")
MODEL = os.environ.get("MIND_MODEL", "openai/switchyard")
PREVIEW = int(os.environ.get("MIND_PREVIEW", "60"))
READING_TYPE = "text/vnd.stewardship-translation.reading"


def rpc(method, params=None, op=None):
    body = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}}
    if op:
        body["operationId"] = op
    req = urllib.request.Request(f"{BACK}/_cpcp/rpc", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


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
    """Which board state is in force. Everything downstream quotes this."""
    state = unwrap(rpc("acia.latest", {"slug": SLUG}))
    if not state.get("ok"):
        return None, state
    return state, None


def preview(document):
    """A bounded look at THAT document -- kinds and titles, by reference.

    Scoped to the document IRI, not to the whole store: the graph is append-only
    and holds every state ever published, so an unscoped query would read across
    boards that are no longer in force.
    """
    # CONTENT, NOT CHROME. 77 of this board's 187 nodes are ActionControls --
    # "Explore this meaning", "Add a frame" -- and Disclosures are the lifecycle
    # stages. Both are how the board WORKS, not what it says. An unfiltered
    # preview spends most of its 60 rows describing buttons to a model asked to
    # read the board, and then the prompt has to talk it back out of them.
    sparql = (
        "PREFIX a: <urn:mm:vocab/acia#> PREFIX p: <urn:mm:vocab/acia/prop#> "
        "SELECT ?kind ?title WHERE { GRAPH ?g { "
        f"?s a:inDocument <{document}> ; a:componentKind ?kind ; p:title ?title "
        "FILTER(?kind != 'ActionControl' && ?kind != 'Disclosure') "
        f"}} }} LIMIT {PREVIEW}"
    )
    rows = unwrap(rpc("graph.query", {"sparql": sparql})).get("rows") or []
    return [{"kind": r.get("kind"), "title": r.get("title")} for r in rows]


def cognition(digest, nodes):
    import asyncio
    from nooa.unifiedllm import CompletionClient
    from mind_agent import build_agent
    # No key: SWITCH is pod-internal and never published. Credentials live there.
    llm = CompletionClient(model=MODEL, api_key="switchyard-local", api_base=SWITCH)
    return asyncio.run(build_agent(llm).read_board(digest, nodes))


def propose(reading, state):
    """A CPCP-grounded action: an operation the seam already admits, carrying an
    operationId derived from the state it read.

    Idempotent by construction -- one reading per board state. Re-reading an
    unchanged board returns BACK's cached receipt rather than a second opinion.
    """
    digest = state["digest"]
    op = "mind-reading-" + hashlib.sha256(digest.encode()).hexdigest()[:16]
    body = f"{reading.title}\n\n{reading.body}"
    params = {
        "operationId": op,
        "bytes": base64.b64encode(body.encode()).decode(),
        "content_type": READING_TYPE,
        "date": time.strftime("%Y-%m-%d", time.gmtime()),
        "name": f"MIND reading: {SLUG}",
        "description": (f"NOOA reading of {state['surface']} at {digest} "
                        f"({reading.node_count} nodes previewed). Proposal, not a finding."),
    }
    return unwrap(rpc("blob.put", params, op=op)), op


def cycle():
    state, refusal = ground()
    if refusal is not None:
        # Nothing published yet is not an error. BACKJOB marks a surface when it
        # first publishes it; until then there is no state to read.
        print(json.dumps({"mind_waiting": refusal}), flush=True)
        return

    nodes = preview(state["document"])
    if not nodes:
        print(json.dumps({"mind_waiting": {"reason": "empty_preview",
                                           "digest": state["digest"]}}), flush=True)
        return

    reading = cognition(state["digest"], nodes)
    receipt, op = propose(reading, state)
    print(json.dumps({"mind_observation": {  # bounded projection -- NOT durable truth
        "nooa": {"version": nooa_version(), "commit": NOOA_COMMIT},
        "grounded_in": state["digest"],
        "operationId": op,
        "proposed": {"title": reading.title, "previewed": len(nodes)},
        "committed_by_back": bool(receipt.get("ok")),
        "stored": receipt.get("digest"),
    }}), flush=True)


def main():
    print(json.dumps({"mind_boot": {"back": BACK, "switch": SWITCH, "slug": SLUG,
                                    "nooa_commit": NOOA_COMMIT,
                                    "nooa_version": nooa_version(),
                                    "egress": "default-deny"}}), flush=True)
    while True:
        try:
            cycle()
        except Exception as e:  # noqa: BLE001
            print(json.dumps({"mind_error": f"{e.__class__.__name__}: {e}"}), flush=True)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
