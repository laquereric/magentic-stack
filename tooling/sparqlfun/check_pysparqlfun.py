#!/usr/bin/env python3
"""PySparqlFun withholds the grant it exists to withhold, and the clue stays blind.

docs/architecture/SparqlFun.md and docs/architecture/TowardsSlms.md name the
gates. These are the ones the built (library) scope covers, exercised against the
real module rather than asserted about it -- a structural grep would pass on code
that imports fine and refuses nothing.

  NO QUERY CROSSES        a `query`/`sparql`/... parameter is REFUSED, not
                          executed and not ignored. Ignoring is worse: the caller
                          believes it was honoured. This is the grant the seam
                          exists to withhold -- arbitrary SPARQL un-scopes a user.

  FRAME OWNS THE PRINCIPAL an argument naming a different userId is
                          principal_override_refused. Neither side wins silently.

  SCOPED LOADS OR FAILS   a scoped capture that never interpolates user_id fails
                          AT LOAD. If it loaded, every request would answer for
                          whichever principal the query happened to select, and
                          that failure looks like data rather than like a bug.

  NO SAMPLING IN A CAPTURE a capture that reaches a model at request time is the
                          thing capture was supposed to replace.

  REPLAY IS REAL          a capture whose examples stop reproducing is
                          capture_unreproducible, not a quietly different answer.

  THE CLUE IS A HEADER    ADR 0019: routing reads headers, never the body. A clue
                          long enough to carry a prompt, or shaped like anything
                          but an opaque name, is refused before it is sent.

  SELECTOR CANNOT AUTHOR  an `author:` clue does not resolve to a function, and
                          an unknown name is a typed refusal rather than a
                          fallback to generating something reasonable.

FAILS CLOSED: no package, or a capture directory that loads nothing, is an error.
"""
from __future__ import annotations

import importlib
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
PKG = ROOT / "runtimes/mind-pod/mind/pysparqlfun"
CAPTURES = PKG / "captures"

errors: list[str] = []


def fail(msg):
    errors.append(msg)


def load(name):
    """Import as the PACKAGE it is, not as a loose file.

    pysparqlfun uses relative imports because it is a package; loading a member
    with spec_from_file_location gives it no parent and the relative import
    fails. Putting mind/ on the path and importing normally exercises the module
    the way MIND will, which is the point of a behavioural gate.
    """
    mind = str(PKG.parent)
    if mind not in sys.path:
        sys.path.insert(0, mind)
    return importlib.import_module("pysparqlfun.%s" % name)


FRAME = {"userId": "u1"}


def exercise(capture_mod, seam, clue):
    captures = capture_mod.load_dir(str(CAPTURES))
    if not captures:
        fail("the capture directory loaded nothing; an empty registry passes every "
             "behavioural assertion below while proving none of them")
        return
    registry = seam.Registry(captures)
    name = captures[0].name

    def execute(_query, bindings, at=None):
        # Stands in for the store hop. Echoes the bindings so the assertions can
        # see WHAT was bound rather than only that something was returned.
        return {"bound": dict(bindings), "at": at}

    # NO QUERY CROSSES.
    for key in ("query", "sparql", "construct"):
        r = seam.call(registry, FRAME, name, "customer:1", params={key: "SELECT * WHERE {?s ?p ?o}"},
                      execute=execute)
        if r.get("ok") or r.get("reason") != "raw_query_refused":
            fail("a %r parameter was not refused: %r" % (key, r))

    # FRAME OWNS THE PRINCIPAL.
    r = seam.call(registry, FRAME, name, "customer:1", params={"user_id": "someone-else"}, execute=execute)
    if r.get("reason") != "principal_override_refused":
        fail("a competing principal was not refused: %r" % r)

    # A matching principal is not an override, and must not be refused.
    r = seam.call(registry, FRAME, name, "customer:1", params={"user_id": "u1"}, execute=execute)
    if not r.get("ok"):
        fail("an argument agreeing with the frame was refused: %r" % r)

    # The frame is required, and empty does not count.
    for bad_frame in ({}, {"userId": ""}, {"userId": None}, "not-a-frame"):
        r = seam.call(registry, bad_frame, name, "customer:1", execute=execute)
        if r.get("reason") != "context_user_required":
            fail("frame %r did not require a userId: %r" % (bad_frame, r))

    # user_id is bound on EVERY execution and comes from the frame.
    r = seam.call(registry, FRAME, name, "customer:1", execute=execute)
    if not r.get("ok"):
        fail("a clean call was refused: %r" % r)
    elif r["result"]["bound"].get("user_id") != "u1":
        fail("user_id was not bound from the frame: %r" % r["result"]["bound"])

    # The answer records the position it was computed at.
    if not r.get("at"):
        fail("a result does not say which corpus position it was computed at; it cannot be re-checked")

    # An unknown function is typed, not a fallback.
    r = seam.call(registry, FRAME, "no_such_capture", "customer:1", execute=execute)
    if r.get("reason") != "unknown_function":
        fail("an unknown function did not refuse by name: %r" % r)

    # A call with no store binding must refuse, not report zero rows.
    r = seam.call(registry, FRAME, name, "customer:1", execute=None)
    if r.get("ok") or r.get("reason") != "graph_unreachable":
        fail("a call with no store binding did not refuse: %r" % r)

    # SCOPED LOADS OR FAILS.
    try:
        capture_mod.Capture.from_dict({
            "name": "unscoped_but_marked", "scoped": True,
            "query": "SELECT ?s WHERE { ?s ?p ?o }",
            "verified_at": "journal:1", "captured_by": "test",
            "examples": [{"id": "x", "expected": []}],
        })
        fail("a scoped capture with no user_id binding loaded; every request would silently "
             "answer for whichever principal the query selected")
    except capture_mod.CaptureError as e:
        if e.reason != "scoped_without_user_binding":
            fail("scoped-without-binding refused with the wrong reason: %s" % e.reason)

    # NO SAMPLING IN A CAPTURE.
    try:
        capture_mod.Capture.from_dict({
            "name": "asks_a_model", "scoped": False,
            "query": "SELECT ?s WHERE { ?s ?p ?o } # then POST to switch /chat/completions",
            "verified_at": "journal:1", "captured_by": "test",
            "examples": [{"id": "x", "expected": []}],
        })
        fail("a capture that reaches a model at request time loaded")
    except capture_mod.CaptureError as e:
        if e.reason != "sampling_inside_capture":
            fail("sampling-inside-capture refused with the wrong reason: %s" % e.reason)

    # A capture with no examples can never be re-checked.
    try:
        capture_mod.Capture.from_dict({
            "name": "unprovable", "scoped": False, "query": "SELECT ?s WHERE { ?s ?p ?o }",
            "verified_at": "journal:1", "captured_by": "test", "examples": [],
        })
        fail("a capture with no examples loaded")
    except capture_mod.CaptureError:
        pass

    # REPLAY IS REAL.
    #
    # The stand-in store is FROZEN HERE, independent of the capture file. An
    # earlier version of this gate answered by echoing the capture's own
    # `expected` back, which meant replay could never disagree with the capture
    # and the check passed no matter what the capture claimed -- exactly the
    # circular pseudo validation this repo has a standing rule against. Caught
    # by a plant that edited a capture and watched the gate stay green.
    #
    # Two independently recorded things is the point, not duplication: the
    # capture records what was verified at journal:0000000042, this records what
    # the store held there, and replay is the comparison. If they disagree, one
    # of them is wrong and a human has to say which.
    STORE_AT_VERIFIED = {
        "customer:1": [["contact:2", "2026-09-02"], ["contact:1", "2026-09-01"]],
        "customer:9": [],
    }

    def replaying(_query, bindings, at=None):
        return STORE_AT_VERIFIED.get(bindings["id"])

    r = seam.replay(registry, FRAME, name, execute=replaying)
    if not r.get("ok"):
        fail("replay of a clean capture did not reproduce: %r" % r)

    r = seam.replay(registry, FRAME, name, execute=lambda *_a, **_k: ["drifted"])
    if r.get("reason") != "capture_unreproducible":
        fail("a drifted store did not produce capture_unreproducible: %r" % r)

    r = seam.replay(registry, FRAME, name, execute=None)
    if r.get("ok"):
        fail("replay with no store binding passed; a replay that runs nothing checks nothing")

    # A registry that FAILED to load must not look like an empty one.
    broken = seam.Registry.from_dir(str(PKG / "no-such-dir"))
    r = seam.functions(broken, FRAME)
    if r.get("ok"):
        fail("a registry that failed to load reported ok; that reads as 'nothing captured yet'")

    # THE CLUE IS A HEADER, AND CARRIES NO CONTENT.
    made = clue.build("select", name)
    if not made.get("ok") or made.get("header") != clue.HEADER:
        fail("a legitimate clue was not built: %r" % made)

    long_value = "select:" + ("a" * 200)
    r = clue.validate(long_value)
    if not r or r.get("reason") != "clue_carries_content":
        fail("a clue long enough to carry a prompt was not refused: %r" % r)

    for bad in ("select:Customer 4815 says the invoice is wrong",
                "select:{\"prompt\": \"...\"}",
                "the whole prompt",
                "select:",
                ""):
        r = clue.validate(bad)
        if not r:
            fail("clue %r was accepted; the grammar is the content rule" % bad)

    # SELECTOR CANNOT AUTHOR.
    r = clue.selected_function("author:%s" % name, registry)
    if r.get("ok") or r.get("reason") != "selector_cannot_author":
        fail("an author clue resolved to a function: %r" % r)

    r = clue.selected_function("select:not_a_capture", registry)
    if r.get("ok") or r.get("reason") != "unknown_function":
        fail("an unknown selection was not a typed refusal: %r" % r)

    r = clue.selected_function("select:%s" % name, registry)
    if not r.get("ok"):
        fail("a valid selection did not resolve: %r" % r)

    # The clue rides beside the pin, and neither comes from the body.
    r = clue.headers("select", name, pin="mlx:ornith")
    if not r.get("ok") or clue.PIN_HEADER not in r["headers"]:
        fail("clue and pin do not ride together as headers: %r" % r)


def main() -> int:
    if not PKG.is_dir():
        print("FAIL: no pysparqlfun package at %s" % PKG, file=sys.stderr)
        emit_population(0)
        return 1

    sources = sorted(PKG.glob("*.py"))
    capture_files = sorted(CAPTURES.glob("*.json")) if CAPTURES.is_dir() else []
    populated, _pop = emit_population(
        len(sources) + len(capture_files), skipped_reason="no pysparqlfun sources and no captures"
    )
    if not populated:
        return 1

    if not capture_files:
        fail("no captures; a seam with nothing to invoke proves nothing about invoking")

    try:
        capture_mod = load("capture")
        seam = load("seam")
        clue = load("clue")
    except Exception as e:  # noqa: BLE001
        print("  FAIL pysparqlfun does not import: %s: %s" % (type(e).__name__, e), file=sys.stderr)
        print("pysparqlfun: FAIL (1)", file=sys.stderr)
        return 1

    try:
        exercise(capture_mod, seam, clue)
    except Exception as e:  # noqa: BLE001
        fail("exercising the seam raised %s: %s -- this module's contract is never-raise"
             % (type(e).__name__, e))

    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("pysparqlfun: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1
    print("pysparqlfun: OK (%d sources, %d captures)" % (len(sources), len(capture_files)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
