import os, uuid
import requests
from flask import Flask, request, jsonify, render_template

BACK = os.environ.get("BACK_URL", "http://back:3000")
app = Flask(__name__)

# The FRONT's three ledgers (POC in-memory; a real FRONT uses local SQLite/OPFS).
STATE = {"mirror": {}, "outbox": [], "private_local": []}


CONTEXT = "https://osi8.poc/context/cyborg-channel"


def rpc(method, params=None):
    # JSON-RPC-LD (not plain JSON-RPC): the params object carries a JSON-LD @context,
    # so the call -- and the grounded records nested inside it, which inherit the
    # context -- is Linked Data. Records also carry @id/@type.
    grounded = {"@context": CONTEXT, **(params or {})}
    r = requests.post(f"{BACK}/rpc",
                      json={"jsonrpc": "2.0", "method": method, "params": grounded, "id": str(uuid.uuid4())},
                      timeout=15)
    return r.json().get("result")


@app.get("/")
def index():
    return render_template("index.html")


@app.get("/state")
def state():
    return jsonify(STATE)


@app.post("/sync-down")
def sync_down():
    recs = rpc("canonical.pull") or []
    STATE["mirror"] = {r["@id"]: r for r in recs}
    return jsonify(STATE)


@app.post("/queue-edit")
def queue_edit():
    b = request.get_json(force=True)
    iid = (b.get("id") or "").strip()
    if iid and iid in STATE["mirror"]:
        base = STATE["mirror"][iid]["sf:version"]
    else:
        iid = f"urn:uuid:{uuid.uuid4()}"
        base = 0
    patch = {"@id": iid, "@type": "Note", "title": b.get("title", ""), "body": b.get("body", "")}
    STATE["outbox"].append({"operationId": str(uuid.uuid4()), "baseVersion": base, "patch": patch})
    return jsonify(STATE)


@app.post("/add-private")
def add_private():
    b = request.get_json(force=True)
    STATE["private_local"].append({"id": str(uuid.uuid4()), "title": b.get("title", ""), "body": b.get("body", "")})
    return jsonify(STATE)


@app.post("/sync-up")
def sync_up():
    results, remaining = [], []
    for intent in STATE["outbox"]:
        rc = rpc("syncIntent.push", {"operationId": intent["operationId"],
                                     "baseVersion": intent["baseVersion"], "patch": intent["patch"]}) or {}
        results.append({"@id": intent["patch"]["@id"], "ok": rc.get("ok"),
                        "reason": rc.get("reason"), "sf:version": rc.get("sf:version")})
        if not rc.get("ok"):
            remaining.append(intent)   # keep conflicted/failed intents for the operator to resolve
    STATE["outbox"] = remaining
    recs = rpc("canonical.pull") or []
    STATE["mirror"] = {r["@id"]: r for r in recs}
    return jsonify({**STATE, "results": results})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
