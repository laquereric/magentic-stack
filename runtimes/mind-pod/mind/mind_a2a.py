"""A2A JSON-RPC frame + JSON-LD grant parts (ADR 0066, 0067).

HTTP is not a fallback. The Part data node IS a CPCP Context or Effect
(@context, type, method, params, operationId). Nested JSON-RPC under
data.cpcp is retired.
"""
from __future__ import annotations

import uuid

A2A_CONTEXT = {
    "@vocab": "https://w3id.org/cpcp/osi8/a2a#",
    "cpcp": "https://w3id.org/cpcp/ns#",
    "id": "@id",
    "type": "@type",
    "operationId": "https://w3id.org/json-rpc-ld/ns#operationId",
}

CPCP_CONTEXT = {
    "@vocab": "https://w3id.org/cpcp/ns#",
    "id": "@id",
    "type": "@type",
    "operationId": "https://w3id.org/json-rpc-ld/ns#operationId",
}


def wrap_cpcp(cpcp: dict) -> dict:
    """Wrap a local {method, params, operationId} dict as A2A message/send."""
    opid = cpcp.get("operationId")
    node = {
        "@context": CPCP_CONTEXT,
        "id": "urn:uuid:%s" % uuid.uuid4(),
        "type": ["Effect", "cpcp:Push"] if opid else ["Context", "cpcp:Pull"],
        "method": cpcp.get("method"),
        "params": cpcp.get("params") or {},
    }
    if opid:
        node["operationId"] = opid
    msg_id = "urn:uuid:%s" % uuid.uuid4()
    return {
        "jsonrpc": "2.0",
        "id": cpcp.get("id", 1),
        "method": "message/send",
        "params": {
            "message": {
                "@context": A2A_CONTEXT,
                "id": msg_id,
                "type": "Message",
                "role": "user",
                "parts": [{
                    "type": "DataPart",
                    "mediaType": "application/ld+json",
                    "data": node,
                }],
            }
        },
    }


def unwrap_cpcp(a2a: dict) -> dict:
    """Return the inner CPCP JSON-LD envelope, or a refusal. Never raises."""
    if not isinstance(a2a, dict):
        return {"ok": False, "reason": "a2a_unparseable", "because": "not an object"}
    if a2a.get("ok") is False:
        return a2a
    err = a2a.get("error")
    if isinstance(err, dict):
        data = err.get("data") if isinstance(err.get("data"), dict) else {}
        return {
            "ok": False,
            "reason": data.get("reason") or err.get("message") or "a2a_error",
            "because": data.get("because") or err,
        }
    result = a2a.get("result")
    if not isinstance(result, dict):
        return {"ok": False, "reason": "a2a_unparseable", "because": "no result"}
    status = result.get("status") if isinstance(result.get("status"), dict) else {}
    artifacts = result.get("artifacts") or []
    for art in artifacts:
        if not isinstance(art, dict):
            continue
        for part in art.get("parts") or []:
            if not isinstance(part, dict):
                continue
            data = part.get("data")
            if not isinstance(data, dict):
                continue
            if isinstance(data.get("cpcp"), dict) and data["cpcp"].get("jsonrpc"):
                return {
                    "ok": False,
                    "reason": "a2a_json_not_jsonld",
                    "because": "nested JSON-RPC under data.cpcp is retired",
                }
            if "ok" in data or "result" in data or "error" in data:
                return data
    reason = status.get("reason") or "a2a_no_cpcp_artifact"
    return {
        "ok": False,
        "reason": reason,
        "because": status.get("because") or "HTTP is not a fallback",
    }
