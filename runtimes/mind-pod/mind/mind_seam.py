"""MIND's CPCP seam (row 10, slice 2). Stdlib only: http.server + json +
hashlib + threading. No NOOA, no harness, no framework imports -- this
module must import on a bare interpreter so the sweep gate can execute it
directly. Run nothing on import.

Three methods (ROW10_SLICE1, approved): mind.reading.latest (pull),
mind.cognition.request (admit, not execute), mind.up (health). Refusals
are non-200 plus envelope (row 49 KEEP BOTH). The seam never dials BACK,
never touches domain state, holds no credential and names no model. What
it serves is an adapter surface over NOOA outputs -- a reading is a lead,
not a fact.

An unconfigured seam refuses everything (no valid tokens exist) but never
kills the cognition cycle: there is no shell for a boot script in this
image, and the cycle must not depend on seam configuration. Default-deny
at the seam, not at the process.
"""
from __future__ import annotations

import hashlib
import json
import os
import threading
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

METHODS = (
    "mind.reading.latest",
    "mind.cognition.request",
    "mind.up",
)

OPS = {
    "mind.reading.latest": "latest",
    "mind.cognition.request": "request",
    "mind.up": "up",
}

ALLOWLIST_OPS = ("latest", "request", "up")

MAX_QUEUE = 32


def max_rows():
    try:
        return max(1, int(os.environ.get("MIND_PREVIEW", "60")))
    except ValueError:
        return 60


class Access:
    """Caller allowlist, 0046 pattern. MIND_CALLERS maps caller id to
    {token, operations}. Missing or unparseable fails closed per call."""

    class Error(Exception):
        def __init__(self, reason, because):
            super().__init__(reason)
            self.reason = reason
            self.because = because

    class Unauthenticated(Error):
        pass

    class Forbidden(Error):
        pass

    class Unparseable(Error):
        pass

    def __init__(self, callers, by_token):
        self.callers = callers
        self.by_token = by_token

    @classmethod
    def parse(cls, raw):
        if raw is None or str(raw).strip() == "":
            raise cls.Unparseable("mind_callers_missing", {"offender": "MIND_CALLERS"})
        try:
            data = json.loads(raw)
        except (ValueError, TypeError):
            raise cls.Unparseable("mind_callers_unparseable", {"offender": "MIND_CALLERS"})
        if not isinstance(data, dict) or not data:
            raise cls.Unparseable(
                "mind_callers_unparseable",
                {"offender": "MIND_CALLERS", "because": "want a non-empty object"},
            )
        callers = {}
        by_token = {}
        for cid, spec in data.items():
            cid = str(cid)
            if not isinstance(spec, dict):
                raise cls.Unparseable(
                    "mind_callers_unparseable",
                    {"offender": cid, "because": "caller spec must be an object"},
                )
            token = str(spec.get("token") or "")
            if not token:
                raise cls.Unparseable("mind_callers_token_missing", {"offender": cid})
            if token in by_token:
                raise cls.Unparseable(
                    "mind_callers_token_collision", {"offender": [by_token[token], cid]}
                )
            ops = [str(o) for o in (spec.get("operations") or []) if isinstance(spec.get("operations"), list)]
            unknown = [o for o in ops if o not in ALLOWLIST_OPS]
            if unknown:
                raise cls.Unparseable(
                    "mind_callers_unknown_operation",
                    {"offender": cid, "because": "want subset of %s" % list(ALLOWLIST_OPS)},
                )
            by_token[token] = cid
            callers[cid] = {"id": cid, "token": token, "operations": ops}
        return cls(callers, by_token)

    def authenticate(self, token):
        cid = self.by_token.get(str(token or ""))
        if not cid or not str(token or ""):
            raise self.Unauthenticated("mind_unauthenticated", {"offender": "Authorization"})
        return self.callers[cid]

    def authorize(self, caller, op):
        if op not in caller["operations"]:
            raise self.Forbidden(
                "mind_forbidden", {"caller": caller["id"], "operation": str(op)}
            )
        return True


class SeamState:
    """In-memory only. A restart clears the latest reading and the admitted
    queue -- both are leads, not truth, and neither may become durable by
    sitting in this process."""

    def __init__(self):
        self.lock = threading.Lock()
        self.latest = None
        self.queue = deque()


def note_reading(state, reading):
    with state.lock:
        state.latest = dict(reading)


def take_request(state):
    with state.lock:
        if not state.queue:
            return None
        return state.queue.popleft()


def fail(reason, because):
    return {"ok": False, "reason": str(reason), "because": because}


def _latest(state):
    if state.latest is None:
        return {"recorded": False}
    out = dict(state.latest)
    out["recorded"] = True
    return out


def _admit(state, params, caller):
    session_iri = params.get("session_iri")
    generation = params.get("generation")
    session_id = params.get("session_id")
    rows = params.get("rows")
    if not isinstance(session_iri, str) or not session_iri.strip():
        return None, fail("invalid_request", {"offender": "session_iri"})
    if isinstance(generation, bool) or not isinstance(generation, int) or generation < 0:
        return None, fail("invalid_request", {"offender": "generation"})
    if session_id is None or (isinstance(session_id, str) and not session_id.strip()):
        return None, fail("invalid_request", {"offender": "session_id"})
    if not isinstance(rows, list) or len(rows) > max_rows():
        return None, fail("invalid_request", {"offender": "rows"})
    key = "%s@%d" % (session_iri, generation)
    request_id = "mind-req-" + hashlib.sha256(key.encode()).hexdigest()[:16]
    with state.lock:
        if len(state.queue) >= MAX_QUEUE:
            return None, fail("mind_queue_full", {"bound": MAX_QUEUE})
        state.queue.append(
            {
                "request_id": request_id,
                "session_iri": session_iri,
                "generation": generation,
                "session_id": session_id,
                "rows": rows,
                "by": caller["id"],
            }
        )
    return {"accepted": True, "request_id": request_id}, None


def _up():
    try:
        import nooa

        version = getattr(nooa, "__version__", "unknown")
    except Exception:
        version = "unavailable"
    return {"ready": True, "surface": "mind-seam", "nooa": version}


def handle_bytes(raw, headers, state):
    """Full RPC surface for one POST body. Returns (status, envelope dict
    with jsonrpc/id merged by the caller). Pure except for state."""
    try:
        access = Access.parse(os.environ.get("MIND_CALLERS"))
    except Access.Unparseable as e:
        return 500, dict(fail(e.reason, e.because), **{"jsonrpc": "2.0", "id": None})
    try:
        parsed = json.loads((raw or b"").decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        return 400, {"ok": False, "reason": "unparseable_json",
                     "because": {"offender": "body"}, "jsonrpc": "2.0", "id": None}
    if not isinstance(parsed, dict):
        return 400, {"ok": False, "reason": "unparseable_json",
                     "because": {"offender": "body"}, "jsonrpc": "2.0", "id": None}
    rid = parsed.get("id")
    params = parsed.get("params")
    if params is None:
        params = {}
    if not isinstance(params, dict):
        return 400, {"ok": False, "reason": "unparseable_json",
                     "because": {"offender": "params"}, "jsonrpc": "2.0", "id": rid}
    method = str(parsed.get("method") or "")
    if method not in METHODS:
        return 400, {"ok": False, "reason": "unknown_operation",
                     "because": {"method": method}, "jsonrpc": "2.0", "id": rid}
    auth = ""
    if isinstance(headers, dict):
        auth = str(headers.get("Authorization") or headers.get("authorization") or "")
    elif headers is not None:
        get = getattr(headers, "get", None)
        if callable(get):
            auth = str(get("Authorization") or "")
    token = auth[len("Bearer "):].strip() if auth.startswith("Bearer ") else ""
    try:
        caller = access.authenticate(token)
        access.authorize(caller, OPS[method])
    except Access.Unauthenticated as e:
        return 401, dict(fail(e.reason, e.because), **{"jsonrpc": "2.0", "id": rid})
    except Access.Forbidden as e:
        return 403, dict(fail(e.reason, e.because), **{"jsonrpc": "2.0", "id": rid})
    op = OPS[method]
    if op == "latest":
        with state.lock:
            result = _latest(state)
        return 200, {"ok": True, "result": result, "jsonrpc": "2.0", "id": rid}
    if op == "up":
        return 200, {"ok": True, "result": _up(), "jsonrpc": "2.0", "id": rid}
    result, refusal = _admit(state, params, caller)
    if refusal is not None:
        if refusal.get("reason") == "mind_queue_full":
            return 429, dict(refusal, **{"jsonrpc": "2.0", "id": rid})
        return 400, dict(refusal, **{"jsonrpc": "2.0", "id": rid})
    return 200, {"ok": True, "result": result, "jsonrpc": "2.0", "id": rid}


class Handler(BaseHTTPRequestHandler):
    state = None

    def log_message(self, *args):  # keep stdout for mind_* JSON lines
        pass

    def _send(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        if status == 401:
            self.send_header("WWW-Authenticate", "Bearer")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/_cpcp/rpc":
            return self._send(404, {"ok": False, "reason": "not_found",
                                    "because": {"path": self.path},
                                    "jsonrpc": "2.0", "id": None})
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = 0
        raw = self.rfile.read(length) if length > 0 else b""
        status, payload = handle_bytes(raw, self.headers, Handler.state)
        self._send(status, payload)

    def do_GET(self):
        return self._send(404, {"ok": False, "reason": "not_found",
                                "because": {"path": self.path},
                                "jsonrpc": "2.0", "id": None})


def start(state, port):
    """Serve the seam on a daemon thread. Returns the server. Raises on
    bind failure -- the caller decides whether cognition survives it."""
    Handler.state = state
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server
