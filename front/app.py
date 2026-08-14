import os, uuid
import requests
from flask import Flask, request, jsonify, render_template

BACK = os.environ.get("BACK_URL", "http://back:3000")
app = Flask(__name__)


def rpc(method, params=None):
    """One JSON-RPC-LD call to BACK over the Level-8 channel."""
    r = requests.post(f"{BACK}/rpc",
                      json={"jsonrpc": "2.0", "method": method, "params": params or {}, "id": str(uuid.uuid4())},
                      timeout=15)
    return r.json().get("result")


@app.get("/")
def index():
    return render_template("index.html")


@app.get("/manifest")
def manifest():
    return jsonify(requests.get(f"{BACK}/manifest", timeout=15).json())


@app.post("/run")
def run():
    """The NOOA-style Profile 2 loop, driven from the browser."""
    body = request.get_json(force=True)
    provider = body.get("provider", "stub")
    api_key = body.get("api_key", "")
    instruction = body.get("instruction", "Mark the first task done.")
    trace = {"provider": provider, "steps": []}

    # 0. BACK publishes the API surface (methods + shapes).
    surface = rpc("methods.list")
    trace["steps"].append({"api_surface": [m["name"] for m in surface]})

    # 1. Read Context BY REFERENCE: bounded previews + @ids (payloads stay in BACK).
    previews = rpc("canonical.pull", {"type": "Task"})
    trace["steps"].append({"read_by_reference": previews})
    if not previews:
        return jsonify({**trace, "error": "no records"})

    # 2. Dereference ONE on demand (canonical.get by @id).
    target = previews[0]
    full = rpc("canonical.get", {"id": target["@id"]})
    trace["steps"].append({"dereferenced": full})
    record = full.get("record", {})

    # 3. The model produces a typed Effect (structured output). Real LLM call is pluggable.
    effect = produce_effect(provider, api_key, instruction, record, trace)

    # 4. Push the Effect back: typed, closed-shape validated, idempotent, version-checked.
    receipt = rpc("syncIntent.push", {
        "operationId": str(uuid.uuid4()),
        "baseVersion": record.get("sf:version"),
        "effect": effect,
    })
    trace["steps"].append({"effect": effect, "receipt": receipt})
    return jsonify(trace)


def produce_effect(provider, api_key, instruction, record, trace):
    """A real deployment calls the SELECTED LLM provider with the previews + instruction,
    constrained by the published shape, to generate this Effect. For the POC we synthesize a
    shape-valid Effect so the loop runs without credentials; wire real calls at call_provider()."""
    effect = {"@id": record.get("@id"), "@type": "Task",
              "title": record.get("title", ""), "status": "done"}
    if provider != "stub" and api_key:
        try:
            produced = call_provider(provider, api_key, instruction, record)
            if produced:
                effect = produced
                trace["steps"].append({"llm": f"{provider} produced structured output"})
            else:
                trace["steps"].append({"llm": f"{provider} hook not wired yet -- stub effect"})
        except Exception as e:  # noqa: BLE001
            trace["steps"].append({"llm_error": str(e), "fallback": "stub effect"})
    else:
        trace["steps"].append({"llm": "stub (no provider/key selected) -- deterministic effect"})
    return effect


def call_provider(provider, api_key, instruction, record):
    """HOOK: implement real provider calls (anthropic / openai / gemini) that return a
    shape-valid Task Effect ({@id,@type:Task,title,status}). Constrain generation with the
    published shape (grammar / structured output) so decode-time == ingest-time. Returns None
    until wired, so the POC falls back to the deterministic stub."""
    return None


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
