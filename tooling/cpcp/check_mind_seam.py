#!/usr/bin/env python3
"""Fail if MIND's seam is more (or less) than the approved surface.

Row 10, slice 2. mind_seam.py is stdlib-only and host-importable, so this
gate executes its dispatch directly: exactly the 3 approved methods, no
framework, no outbound dialing, no domain writes, refusals non-200 plus
envelope. Anything the seam gains must arrive with its checker update.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import ast
import importlib.util
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SEAM = Path("runtimes/mind-pod/mind/mind_seam.py")
DOCKERFILE = Path("runtimes/mind-pod/mind/Dockerfile")
COMPOSE_FILES = (
    Path("runtimes/mind-pod/docker-compose.yml"),
    Path("runtimes/mind-pod/app/extract/compose.yml"),
)
WANT_METHODS = ("mind.reading.latest", "mind.cognition.request", "mind.up")
STDLIB = {"hashlib", "json", "os", "threading", "collections", "http", "__future__"}
CALLERS = '{"op": {"token": "s3", "operations": ["latest", "request", "up"]}, "ro": {"token": "r0", "operations": ["up"]}}'


def fail_empty_check_root():
    if "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return True
    return False


def root_from_env():
    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    return Path(raw)


def load_seam(root):
    path = root / SEAM
    spec = importlib.util.spec_from_file_location("mind_seam_under_test", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def rpc(mod, state, method, params=None, token="s3", callers=CALLERS, raw=None):
    old = os.environ.get("MIND_CALLERS")
    os.environ["MIND_CALLERS"] = callers
    try:
        if raw is not None:
            body = raw
        else:
            body = json.dumps({"jsonrpc": "2.0", "id": 7, "method": method,
                               "params": params or {}}).encode()
        headers = {"Authorization": "Bearer %s" % token} if token else {}
        return mod.handle_bytes(body, headers, state)
    finally:
        if old is None:
            os.environ.pop("MIND_CALLERS", None)
        else:
            os.environ["MIND_CALLERS"] = old


def main():
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1
    try:
        nonempty = any(root.iterdir())
    except OSError as e:
        print("FAIL: CHECK_ROOT unreadable: %s" % e, file=sys.stderr)
        return 1
    if not nonempty:
        print("FAIL: empty CHECK_ROOT tree", file=sys.stderr)
        return 1

    errors = []
    examined = 0

    examined += 1
    src_path = root / SEAM
    if not src_path.is_file():
        print("FAIL: missing %s" % SEAM.as_posix(), file=sys.stderr)
        emit_population(0)
        return 1
    src = src_path.read_text(encoding="utf-8")
    print("  ok %s" % SEAM.as_posix())

    examined += 1
    try:
        tree = ast.parse(src)
    except SyntaxError as e:
        errors.append("mind_seam.py does not parse: %s" % e)
        tree = None
    if tree is not None:
        top, local = set(), set()
        for node in tree.body:
            if isinstance(node, ast.Import):
                top.update(a.name.split(".")[0] for a in node.names)
            elif isinstance(node, ast.ImportFrom):
                top.add((node.module or "").split(".")[0])
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                for sub in ast.walk(node):
                    if isinstance(sub, ast.Import):
                        local.update(a.name.split(".")[0] for a in sub.names)
                    elif isinstance(sub, ast.ImportFrom):
                        local.add((sub.module or "").split(".")[0])
        top.discard("")
        extra = sorted(g for g in top if g not in STDLIB)
        if extra:
            errors.append("mind_seam.py imports beyond stdlib allowlist: %s" % extra)
        else:
            print("  ok stdlib-only top-level imports %s" % sorted(top))
        local_extra = sorted(g for g in local if g not in STDLIB and g != "nooa")
        if local_extra:
            errors.append("mind_seam.py function-local imports beyond allowlist: %s" % local_extra)
        else:
            print("  ok function-local imports confined (nooa version report only)")

    for token_word in ("urllib", "BACK_URL", "sqlite"):
        examined += 1
        if token_word in src:
            errors.append("mind_seam.py contains %r (seam never dials BACK or writes stores)" % token_word)
        else:
            print("  ok no %s in seam" % token_word)
    examined += 1
    # Lowercase "nooa" appears only in _up()'s guarded version report
    # (docstring uses NOOA). Anything else is the seam driving cognition.
    nooa_lines = [ln.strip() for ln in src.splitlines()
                  if "nooa" in ln and not ln.strip().startswith("#")]
    allowed = {'import nooa', 'version = getattr(nooa, "__version__", "unknown")',
               'return {"ready": True, "surface": "mind-seam", "nooa": version}'}
    bad = [ln for ln in nooa_lines if ln not in allowed]
    if bad:
        errors.append("mind_seam.py reaches past version-reporting into NOOA: %r" % bad)
    else:
        print("  ok NOOA only version-reported, never driven")

    examined += 1
    try:
        mod = load_seam(root)
    except Exception as e:  # noqa: BLE001
        errors.append("mind_seam.py does not import clean: %s: %s" % (e.__class__.__name__, e))
        mod = None
    if mod is not None:
        print("  ok seam imports without NOOA")
        examined += 1
        if tuple(mod.METHODS) != WANT_METHODS:
            errors.append("METHODS is %r, want exactly %r" % (tuple(mod.METHODS), WANT_METHODS))
        else:
            print("  ok exactly the 3 approved methods")

        st = mod.SeamState()
        examined += 1
        status, env = rpc(mod, st, "nope.nope")
        if status != 400 or env.get("reason") != "unknown_operation" or env.get("id") != 7 or "jsonrpc" not in env:
            errors.append("unknown method is not 400+envelope: %d %r" % (status, env))
        else:
            print("  ok unknown method 400+envelope")

        examined += 1
        status, env = rpc(mod, st, "mind.up", token="")
        if status != 401 or env.get("reason") != "mind_unauthenticated":
            errors.append("missing token is not 401: %d %r" % (status, env))
        else:
            print("  ok missing token 401")

        examined += 1
        status, env = rpc(mod, st, "mind.reading.latest", token="r0")
        if status != 403 or env.get("reason") != "mind_forbidden":
            errors.append("unallowlisted op is not 403: %d %r" % (status, env))
        else:
            print("  ok unallowlisted op 403")

        examined += 1
        status, env = rpc(mod, st, "mind.reading.latest")
        if status != 200 or env.get("result", {}).get("recorded") is not False:
            errors.append("empty latest is not recorded:false: %d %r" % (status, env))
        else:
            print("  ok latest recorded:false before first reading")
        mod.note_reading(st, {"title": "t"})
        status, env = rpc(mod, st, "mind.reading.latest")
        if status != 200 or env.get("result", {}).get("title") != "t":
            errors.append("latest does not return the retained reading: %d %r" % (status, env))
        else:
            print("  ok latest returns retained reading")

        examined += 1
        bad = [
            ({}, "missing session_iri"),
            ({"session_iri": "s", "generation": -1, "session_id": 1, "rows": []}, "negative generation"),
            ({"session_iri": "s", "generation": True, "session_id": 1, "rows": []}, "bool generation"),
            ({"session_iri": "s", "generation": 0, "session_id": 1, "rows": "x"}, "non-list rows"),
            ({"session_iri": "s", "generation": 0, "session_id": 1, "rows": list(range(61))}, "overlong rows"),
        ]
        for params, why in bad:
            status, env = rpc(mod, st, "mind.cognition.request", params)
            if status != 400 or env.get("reason") != "invalid_request":
                errors.append("request %s is not 400 invalid_request: %d %r" % (why, status, env))
                break
        else:
            print("  ok malformed requests 400")
        examined += 1
        status, env = rpc(mod, mod.SeamState(), "mind.cognition.request",
                           {"session_iri": "s", "generation": 3, "session_id": 9, "rows": []})
        if status != 200 or not str(env.get("result", {}).get("request_id", "")).startswith("mind-req-"):
            errors.append("valid request is not accepted: %d %r" % (status, env))
        else:
            print("  ok valid request accepted with request_id")

        examined += 1
        full = mod.SeamState()
        for i in range(mod.MAX_QUEUE):
            rpc(mod, full, "mind.cognition.request",
                {"session_iri": "s%d" % i, "generation": 0, "session_id": 1, "rows": []})
        status, env = rpc(mod, full, "mind.cognition.request",
                           {"session_iri": "overflow", "generation": 0, "session_id": 1, "rows": []})
        if status != 429 or env.get("reason") != "mind_queue_full":
            errors.append("full queue is not 429: %d %r" % (status, env))
        else:
            print("  ok full queue 429")

        examined += 1
        status, env = rpc(mod, st, "mind.up")
        if status != 200 or env.get("result", {}).get("ready") is not True:
            errors.append("up is not ready: %d %r" % (status, env))
        else:
            print("  ok up ready")

        examined += 1
        status, env = rpc(mod, st, "mind.up", raw=b"")
        if status != 400 or env.get("reason") != "unparseable_json":
            errors.append("empty body is not 400: %d %r" % (status, env))
        else:
            print("  ok empty body 400")

        examined += 1
        old = os.environ.pop("MIND_CALLERS", None)
        try:
            status, env = mod.handle_bytes(
                json.dumps({"jsonrpc": "2.0", "id": 1, "method": "mind.up"}).encode(),
                {}, mod.SeamState())
        finally:
            if old is not None:
                os.environ["MIND_CALLERS"] = old
        if status != 500 or env.get("reason") != "mind_callers_missing":
            errors.append("unconfigured seam is not 500: %d %r" % (status, env))
        else:
            print("  ok unconfigured seam 500s, cycle untouched")

    examined += 1
    df = (root / DOCKERFILE).read_text(encoding="utf-8", errors="replace") if (root / DOCKERFILE).is_file() else ""
    if "mind_seam.py" not in df:
        errors.append("mind Dockerfile does not COPY mind_seam.py")
    elif "EXPOSE" not in df:
        errors.append("mind Dockerfile declares no EXPOSE")
    else:
        print("  ok Dockerfile ships the seam")

    for rel in COMPOSE_FILES:
        examined += 1
        p = root / rel
        text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
        if not p.is_file():
            errors.append("missing %s" % rel.as_posix())
            continue
        m = re.search(r"^  mind:\s*$", text, re.M)
        if not m:
            errors.append("%s has no mind service" % rel.as_posix())
            continue
        rest = text[m.end():]
        nxt = re.search(r"^  [A-Za-z0-9_-]+:\s*$", rest, re.M)
        top = re.search(r"^[A-Za-z]", rest, re.M)
        cuts = [i.start() for i in (nxt, top) if i]
        svc = rest[: min(cuts)] if cuts else rest
        if "MIND_CALLERS" not in svc:
            errors.append("%s mind service sets no MIND_CALLERS" % rel.as_posix())
        elif re.search(r"^\s+ports:", svc, re.M):
            errors.append("%s mind seam is host-published" % rel.as_posix())
        elif "8091" not in svc:
            errors.append("%s mind service does not expose the seam port" % rel.as_posix())
        else:
            print("  ok %s mind unpublished with callers" % rel.as_posix())

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("MIND SEAM FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("mind seam: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
