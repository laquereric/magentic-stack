#!/usr/bin/env python3
"""Step 5: generated/runtime artifact verification at live wrap sites.

For every CpcpAdapter.wrap, compare the TTL NodeShape (source) to the Ruby
Grounding branch (first compiler backend) via ClosedShapeIR.

If they disagree, RECORD the disagreement. Do not edit TTL or Ruby to make
this pass. Stored `divergences[]` is the key this checker reads.

A planted extra Ruby property, or a planted extra TTL property, must fire
and NAME that property. Empty CHECK_ROOT fails closed.

ADR 0042b: `seam_skip[]` is the skip list Grounding uses for closed extras.
A planted extra skip-list entry, or a reintroduced @-prefix wildcard, must
fire. The checker reads `seam_skip[]` and `seam_skip_wildcard`.

Does not move TTL, edit shapes, or touch config.shape_root.
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from population import emit_population
from shape_compiler import Source, RubyBackend, parse_wraps, compare, divergence_key

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
STORED = ROOT / "tooling/shacl/shape_runtime_artifact.json"


def live():
    wraps = parse_wraps(ROOT)
    src = Source(ROOT).shapes()
    be = RubyBackend(ROOT)
    divergences = compare(wraps, src, be.shapes())
    return {
        "schema": "shape-runtime-artifact/v0",
        "backend": "ruby",
        "compiler_interface": "ClosedShapeIR",
        "nothing_reconciled": True,
        "wrap_sites": len(wraps),
        "shapes_compared": len(wraps) * 2,
        "divergence_count": len(divergences),
        "seam_skip": be.seam_skip(),
        "seam_skip_wildcard": be.seam_skip_wildcard(),
        "wraps": [
            {"operation": w.operation, "file": w.file, "line": w.line,
             "request_shape": w.request_shape, "response_shape": w.response_shape}
            for w in wraps
        ],
        "divergences": divergences,
    }


def check(stored, live_doc):
    errors = []
    live_d = {divergence_key(d): d for d in live_doc.get("divergences", [])}
    stored_d = {divergence_key(d): d for d in stored.get("divergences", [])}
    missing = sorted(set(live_d) - set(stored_d))
    extra = sorted(set(stored_d) - set(live_d))
    # THE KEY THE CHECKER READS.
    if missing:
        for k in missing[:20]:
            d = live_d[k]
            errors.append(
                "UNRECORDED DIVERGENCE: %s at %s property=%s kind=%s"
                % (d["shape"], d["wrap_site"], d.get("property"), d["kind"])
            )
    if extra:
        for k in extra[:20]:
            d = stored_d[k]
            errors.append(
                "STORED DIVERGENCE ABSENT FROM LIVE: %s at %s property=%s kind=%s"
                % (d["shape"], d.get("wrap_site"), d.get("property"), d.get("kind"))
            )
    if live_doc.get("wrap_sites") != stored.get("wrap_sites"):
        errors.append("wrap_sites live=%s stored=%s"
                      % (live_doc.get("wrap_sites"), stored.get("wrap_sites")))
    # ADR 0042b: the skip list is a checker-visible constant. Changing it, or
    # reopening it with an @-prefix wildcard, must fail.
    if live_doc.get("seam_skip_wildcard"):
        errors.append(
            "SEAM SKIP WILDCARD: seam_identity_key? matches @-prefix; skip list is not closed"
        )
    live_skip = list(live_doc.get("seam_skip") or [])
    stored_skip = list(stored.get("seam_skip") or [])
    if live_skip != stored_skip:
        errors.append("SEAM SKIP CHANGED live=%s stored=%s" % (live_skip, stored_skip))
    return errors


def main(argv):
    write = "--write" in argv
    try:
        import rdflib  # noqa: F401
    except ImportError as e:
        print("FAIL-CLOSED: missing dependency: %s" % e, file=sys.stderr)
        return 1

    doc = live()
    n = doc["shapes_compared"]
    populated, _pop = emit_population(
        n, skipped_reason="no CpcpAdapter.wrap sites / no shapes compared"
    )
    if not populated:
        return 1

    if write:
        STORED.parent.mkdir(parents=True, exist_ok=True)
        STORED.write_text(json.dumps(doc, indent=2) + "\n")
        print("wrote", STORED.relative_to(ROOT) if ROOT in STORED.parents else STORED)
        print("wrap_sites", doc["wrap_sites"], "shapes_compared", n,
              "divergences", doc["divergence_count"],
              "seam_skip", doc.get("seam_skip"))
        return 0

    if not STORED.is_file():
        print("FAIL-CLOSED: missing", STORED, file=sys.stderr)
        return 1
    stored = json.loads(STORED.read_text())
    errors = check(stored, doc)
    print("wrap_sites", doc["wrap_sites"], "shapes_compared", n,
          "divergences", doc["divergence_count"],
          "seam_skip", doc.get("seam_skip"),
          "wildcard", doc.get("seam_skip_wildcard"))
    if errors:
        print("SHAPE RUNTIME ARTIFACT FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        return 1
    print("shape runtime artifact: OK (%d wrap sites, %d shapes, %d recorded divergences, seam_skip=%s)"
          % (doc["wrap_sites"], n, doc["divergence_count"], doc.get("seam_skip")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
