#!/usr/bin/env python3
"""Fail if a live /_cpcp server has no authority, or a new seam is undeclared.

Gap 20. ADR 0050: each additional seam must state what it is authoritative
for. Count is measured: live vs decided-unbuilt, not inherited from 0050
or the row. kind=server files from cpcp_callers.json must belong to a
live seam. A live seam with empty authoritative_for fails.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

TABLE = Path("tooling/cpcp/seam_authority.json")
CALLERS = Path("tooling/cpcp/cpcp_callers.json")


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


def load_json(path: Path):
    if not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


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
    table = load_json(root / TABLE)
    callers = load_json(root / CALLERS)
    if table is None:
        print("FAIL: missing %s" % TABLE.as_posix(), file=sys.stderr)
        emit_population(0)
        return 1
    if callers is None:
        print("FAIL: missing %s" % CALLERS.as_posix(), file=sys.stderr)
        emit_population(0)
        return 1

    live = table.get("live") or []
    unbuilt = table.get("decided_unbuilt") or []
    not_seams = table.get("not_a_seam") or []
    served = {}
    domain_writers = []

    for row in live:
        sid = row.get("id") or "(unnamed)"
        auth = (row.get("authoritative_for") or "").strip()
        if not auth:
            errors.append("live seam %s has empty authoritative_for" % sid)
        if "domain_writer" not in row or not isinstance(row.get("domain_writer"), bool):
            errors.append("live seam %s missing boolean domain_writer" % sid)
        if row.get("domain_writer") is True:
            domain_writers.append(sid)
        files = row.get("served_by") or []
        if not files:
            errors.append("live seam %s has empty served_by" % sid)
        for rel in files:
            if rel in served:
                errors.append("file %s claimed by both %s and %s" % (rel, served[rel], sid))
            served[rel] = sid
            p = root / rel
            if not p.is_file():
                errors.append("live seam %s served_by missing %s" % (sid, rel))
            elif "_cpcp/rpc" not in p.read_text(encoding="utf-8", errors="replace"):
                errors.append("live seam %s served_by %s has no _cpcp/rpc token" % (sid, rel))
            else:
                print("  ok live %s <- %s" % (sid, rel))

    if domain_writers != ["back"]:
        errors.append(
            "domain_writer true must be exactly [back], got %s (ADR 0056: BACKJOB writes locally, does not mount /_cpcp)"
            % domain_writers
        )
    else:
        print("  ok only back seam admits domain writes")

    layers = table.get("layers") or {}
    for layer in ("http", "cpcp", "rest", "w3id"):
        spec = layers.get(layer) or {}
        if not (spec.get("authoritative_for") or "").strip() or not (spec.get("must_not_decide") or "").strip():
            errors.append("layers.%s lacks authority or prohibition (row 105)" % layer)
        else:
            print("  ok layer %s declares authority and prohibition" % layer)
    for row in live:
        bindings = row.get("bindings") or []
        if not bindings or any(b not in ("http", "cpcp", "rest", "w3id") for b in bindings):
            errors.append("live seam %s declares no known layers (row 105: name what you translate)" % row.get("id"))
        else:
            print("  ok live %s binds %s" % (row.get("id"), bindings))

    for row in unbuilt:
        sid = row.get("id") or "(unnamed)"
        if not (row.get("authoritative_for") or "").strip():
            errors.append("decided-unbuilt seam %s has empty authoritative_for" % sid)
        if row.get("served_by"):
            errors.append("decided-unbuilt seam %s must not have served_by (it is unbuilt)" % sid)
        if row.get("domain_writer") is True:
            errors.append("decided-unbuilt seam %s must not be domain_writer" % sid)
        print("  ok unbuilt %s" % sid)

    for row in not_seams:
        if not (row.get("id") and (row.get("because") or "").strip()):
            errors.append("not_a_seam row missing id or because")
        else:
            print("  ok not-a-seam %s" % row["id"])

    server_files = [
        e.get("file") for e in (callers.get("entries") or [])
        if e.get("kind") == "server"
    ]
    for rel in server_files:
        if rel not in served:
            errors.append(
                "cpcp_callers kind=server %s is not on a live seam (new seam without authority)"
                % rel
            )
        else:
            print("  ok server %s on seam %s" % (rel, served[rel]))
    extra = sorted(set(served) - set(server_files))
    if extra:
        errors.append("seam served_by not kind=server in cpcp_callers: %s" % extra)

    n_live = len(live)
    n_unbuilt = len(unbuilt)
    print("  live seams: %d %s" % (n_live, [r.get("id") for r in live]))
    print("  decided-unbuilt seams: %d %s" % (n_unbuilt, [r.get("id") for r in unbuilt]))
    print("  not-a-seam: %d %s" % (len(not_seams), [r.get("id") for r in not_seams]))
    print("  0050 said four; row 20 said five; measured live=%d unbuilt=%d (row 18 collapsed SwitchYard CPCP into bus)" % (
        n_live, n_unbuilt))

    examined = n_live + n_unbuilt + len(not_seams) + len(server_files)
    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("SEAM AUTHORITY FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        return 1
    print("seam authority: OK (live %d, decided-unbuilt %d)" % (n_live, n_unbuilt))
    return 0


if __name__ == "__main__":
    sys.exit(main())
