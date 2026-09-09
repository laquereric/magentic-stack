#!/usr/bin/env python3
"""Fail if in-pod A2A reintroduces HTTP, or internet A2A drifts.

ADR 0066: intrapod A2A rides NATS. preferredTransport is NATS. MIND
calls a2a.back.rpc when MM_NATS_URL is set. HTTP is not a fallback.
The intrapod binding must not serve /.well-known/agent-card.

ADR 0068: internet A2A is host-published HTTP
(GET /.well-known/agent-card.json, POST /_a2a/rpc), 404 on loopback.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

A2A_RB = Path("gems/rails-cpcp/lib/rails_cpcp/a2a_binding.rb")
A2A_INET = Path("gems/rails-cpcp/lib/rails_cpcp/a2a_internet.rb")
A2A_CTRL = Path("runtimes/mind-pod/app/app/controllers/a2a_internet_controller.rb")
ROUTES = Path("runtimes/mind-pod/app/config/routes.rb")
HARNESS = Path("runtimes/mind-pod/mind/harness.py")
MIND_A2A = Path("runtimes/mind-pod/mind/mind_a2a.py")
REQUIRED = "HTTP is not a fallback"


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
    rb = root / A2A_RB
    text = rb.read_text(encoding="utf-8", errors="replace") if rb.is_file() else ""
    if not text:
        errors.append("missing %s" % A2A_RB.as_posix())
    else:
        print("  ok %s" % A2A_RB.as_posix())
        if 'preferredTransport" => "NATS"' not in text and "preferredTransport'] = 'NATS'" not in text:
            if '"preferredTransport" => "NATS"' not in text:
                errors.append("Agent Card preferredTransport is not NATS")
        if "a2a.#{for_agent}.rpc" not in text and "a2a.back.rpc" not in text:
            errors.append("A2A NATS subject a2a.<agent>.rpc missing")
        if "/.well-known/" in text:
            errors.append("in-pod A2A must not serve /.well-known/agent-card")
        if "application/ld+json" not in text:
            errors.append("A2A DataPart mediaType application/ld+json missing")
        if "a2a_json_not_jsonld" not in text:
            errors.append("retired nested JSON-RPC nest must be refused as a2a_json_not_jsonld")
        if REQUIRED not in text:
            errors.append("%s missing %r" % (A2A_RB.as_posix(), REQUIRED))
        if 'header: hdr' not in text and "header: hdr" not in text:
            errors.append("A2A NATS request must carry Authorization as a NATS header")

    examined += 1
    inet = root / A2A_INET
    itext = inet.read_text(encoding="utf-8", errors="replace") if inet.is_file() else ""
    if not itext:
        errors.append("missing %s" % A2A_INET.as_posix())
    else:
        print("  ok %s" % A2A_INET.as_posix())
        if '"preferredTransport" => "HTTP"' not in itext:
            errors.append("internet Agent Card preferredTransport is not HTTP")
        if "/.well-known/agent-card.json" not in itext:
            errors.append("internet A2A must name /.well-known/agent-card.json")
        if "HTTP_BIND" not in itext:
            errors.append("internet A2A must gate on HTTP_BIND (loopback does not speak it)")
        if "nats://" in itext:
            errors.append("internet Agent Card must not advertise the in-pod NATS URL")
        if REQUIRED not in itext:
            errors.append("%s missing %r" % (A2A_INET.as_posix(), REQUIRED))

    examined += 1
    ctrl = root / A2A_CTRL
    ctext = ctrl.read_text(encoding="utf-8", errors="replace") if ctrl.is_file() else ""
    if not ctext:
        errors.append("missing %s" % A2A_CTRL.as_posix())
    elif "head :not_found" not in ctext:
        errors.append("internet A2A controller must 404 when the process does not speak it")
    else:
        print("  ok %s" % A2A_CTRL.as_posix())

    examined += 1
    rt = root / ROUTES
    rtext = rt.read_text(encoding="utf-8", errors="replace") if rt.is_file() else ""
    if not rtext:
        errors.append("missing %s" % ROUTES.as_posix())
    else:
        print("  ok %s" % ROUTES.as_posix())
        if "/.well-known/agent-card.json" not in rtext:
            errors.append("ROLE=back must route GET /.well-known/agent-card.json")
        if "/_a2a/rpc" not in rtext:
            errors.append("ROLE=back must route POST /_a2a/rpc")

    examined += 1
    h = root / HARNESS
    ht = h.read_text(encoding="utf-8", errors="replace") if h.is_file() else ""
    if not ht:
        errors.append("missing %s" % HARNESS.as_posix())
    elif "a2a.back.rpc" not in ht:
        errors.append("MIND harness does not call a2a.back.rpc under MM_NATS_URL")
    else:
        print("  ok harness a2a.back.rpc")

    examined += 1
    ma = root / MIND_A2A
    mt = ma.read_text(encoding="utf-8", errors="replace") if ma.is_file() else ""
    if not mt:
        errors.append("missing %s" % MIND_A2A.as_posix())
    elif REQUIRED not in mt:
        errors.append("%s missing %r" % (MIND_A2A.as_posix(), REQUIRED))
    elif "application/ld+json" not in mt:
        errors.append("%s wrap is not JSON-LD" % MIND_A2A.as_posix())
    elif '"cpcp": cpcp' in mt or "'cpcp': cpcp" in mt:
        errors.append("%s still nests JSON under data.cpcp" % MIND_A2A.as_posix())
    else:
        print("  ok %s" % MIND_A2A.as_posix())

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("A2A FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("a2a: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
