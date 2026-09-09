"""A2A envelope helpers for in-pod agent calls over NATS (ADR 0066).

HTTP is not a fallback. Wrap a CPCP PDU as Part data.cpcp; unwrap the
Task artifact back to the CPCP envelope MIND already consumes.
"""
from __future__ import annotations

import json
import uuid


def wrap_cpcp(cpcp: dict) -> dict:
    return {
        "jsonrpc": "2.0",
        "id": cpcp.get("id", 1),
        "method": "message/send",
        "params": {
            "message": {
                "messageId": str(uuid.uuid4()),
                "role": "user",
                "parts": [{"kind": "data", "data": {"cpcp": cpcp}}],
            }
        },
    }


def unwrap_cpcp(a2a: dict) -> dict:
    """Return the inner CPCP envelope, or a refusal. Never raises."""
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
            if isinstance(data, dict) and isinstance(data.get("cpcp"), dict):
                return data["cpcp"]
    reason = status.get("reason") or "a2a_no_cpcp_artifact"
    return {
        "ok": False,
        "reason": reason,
        "because": status.get("because") or "HTTP is not a fallback",
    }
