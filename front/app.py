import os, uuid, json
from collections import defaultdict
import requests
from flask import Flask, request, jsonify, render_template

BACK = os.environ.get("BACK_URL", "http://back:3000")
ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-3-5-sonnet-latest")
app = Flask(__name__)
MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]


def rpc(method, params=None):
    r = requests.post(f"{BACK}/rpc",
                      json={"jsonrpc": "2.0", "method": method, "params": params or {}, "id": str(uuid.uuid4())},
                      timeout=60)
    return r.json().get("result")


@app.get("/")
def index():
    return render_template("index.html")


@app.get("/manifest")
def manifest():
    return jsonify(requests.get(f"{BACK}/manifest", timeout=15).json())


@app.post("/run")
def run():
    body = request.get_json(force=True)
    provider = body.get("provider", "stub")
    api_key = body.get("api_key", "")
    question = body.get("instruction", "Are sales seasonal?")
    trace = {"provider": provider, "steps": []}

    surface = rpc("methods.list")
    trace["steps"].append({"api_surface": [m["name"] for m in surface]})

    # Read Context BY REFERENCE: bounded dataset previews + @ids (the 60-point series stays in BACK).
    previews = rpc("canonical.pull", {"type": "Dataset"})
    trace["steps"].append({"read_by_reference": previews})
    ds = next((p for p in previews if p["@type"] == "Dataset"), None)
    if not ds:
        return jsonify({**trace, "error": "no dataset"})

    # Dereference ON DEMAND to get the full series.
    full = rpc("canonical.get", {"id": ds["@id"]})
    record = full.get("record", {})
    trace["steps"].append({"dereferenced": {"@id": record.get("@id"), "@type": record.get("@type"),
                                            "title": record.get("title"), "points": record.get("points")}})

    # The model produces a STRUCTURED Insight (answer grounded in the referenced data).
    insight, note = produce_insight(provider, api_key, question, record)
    trace["steps"].append({"model": note})

    # Push the structured output back: validated against the closed Insight shape, idempotent, receipted.
    receipt = rpc("insight.push", {"operationId": str(uuid.uuid4()), "insight": insight})
    trace["steps"].append({"insight": insight, "receipt": receipt})
    trace["answer"] = insight.get("answer")
    return jsonify(trace)


def produce_insight(provider, api_key, question, record):
    if provider != "stub" and api_key:
        try:
            produced = call_provider(provider, api_key, question, record)
            if produced:
                return produced, f"{provider} produced a structured Insight"
            return stub_insight(question, record), f"{provider} unavailable -- deterministic analysis"
        except Exception as e:  # noqa: BLE001
            return stub_insight(question, record), f"{provider} error ({e}) -- deterministic analysis"
    return stub_insight(question, record), "stub (no provider/key) -- deterministic analysis"


def stub_insight(question, record):
    """A deterministic analysis computed from the referenced data, so the loop answers
    without an LLM. A real provider (below) does this with the model."""
    series = record.get("series", [])
    by_month = defaultdict(list)
    for p in series:
        by_month[p["month"]].append(p["sales"])
    avg = {m: sum(v) / len(v) for m, v in by_month.items()}
    peak, trough = max(avg, key=avg.get), min(avg, key=avg.get)
    ratio = avg[peak] / avg[trough] if avg.get(trough) else 0
    seasonal = ratio > 1.2
    ans = (f"Yes -- sales are seasonal. The peak month is {MONTHS[peak-1]} (5-yr avg ${avg[peak]:,.0f}) "
           f"and the trough is {MONTHS[trough-1]} (${avg[trough]:,.0f}), about a {ratio:.1f}x swing, "
           f"repeating every year.") if seasonal else "No strong seasonality is evident in the series."
    return {"@type": "Insight", "question": question, "answer": ans, "seasonal": bool(seasonal),
            "evidence": f"Monthly averages across {len(series)//12} years; peak/trough ratio {ratio:.2f}."}


def call_provider(provider, api_key, question, record):
    if provider == "anthropic":
        return call_anthropic(api_key, question, record)
    # openai / gemini: same shape-constrained pattern; left for follow-up (falls back to stub).
    return None


def call_anthropic(api_key, question, record):
    """Real Anthropic call. The published Insight shape is compiled into a forced tool so the
    model's decode-time output == the ingest-time closed shape (Profile 2 double enforcement)."""
    tool = {
        "name": "submit_insight",
        "description": "Return the analysis of the dataset as a structured Insight.",
        "input_schema": {
            "type": "object",
            "properties": {
                "answer": {"type": "string", "description": "the analytical answer, grounded in the data"},
                "seasonal": {"type": "boolean"},
                "evidence": {"type": "string", "description": "the numbers that support the answer"},
            },
            "required": ["answer"],
        },
    }
    content = (f"You are a data analyst. Dataset '{record.get('title')}' (unit {record.get('unit')}). "
               f"Monthly series as JSON:\n{json.dumps(record.get('series', []))}\n\n"
               f"Question: {question}\nCall submit_insight with your answer.")
    r = requests.post(
        "https://api.anthropic.com/v1/messages",
        headers={"x-api-key": api_key, "anthropic-version": "2023-06-01", "content-type": "application/json"},
        json={"model": ANTHROPIC_MODEL, "max_tokens": 1024, "tools": [tool],
              "tool_choice": {"type": "tool", "name": "submit_insight"},
              "messages": [{"role": "user", "content": content}]},
        timeout=90)
    data = r.json()
    if "error" in data:
        raise RuntimeError(data["error"].get("message", "anthropic error"))
    for block in data.get("content", []):
        if block.get("type") == "tool_use":
            inp = block["input"]
            out = {"@type": "Insight", "question": question, "answer": inp.get("answer", "")}
            if "seasonal" in inp:
                out["seasonal"] = bool(inp["seasonal"])
            if inp.get("evidence"):
                out["evidence"] = inp["evidence"]
            return out
    return None


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
