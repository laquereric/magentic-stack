"""The three methods, never-raise, with CPCP embedded so the caller holds an id.

docs/architecture/SparqlFun.md names sparqlfun.call / .functions / .replay and
what each refuses. This is that, as a library: the container form is blocked on
the ADR 0047 language-rule call (a second Python service), and none of the
behaviour below depends on which way that goes.

WHAT "BATTERIES INCLUDED" MEANS HERE. The caller supplies a ContextFrame and an
event id. It does not supply SPARQL, an endpoint, a credential, a prefix map, a
graph name, a retry policy, a subject name, or an envelope. All of that is
inside. The point is not convenience -- it is that a caller who cannot express a
query cannot express a query that un-scopes someone.

THE GRANT THIS SEAM WITHHOLDS. `graph.query` takes a SPARQL string and is a
different grant: an agent that can send arbitrary SPARQL can read any principal's
rows. So a `query` (or `sparql`) parameter here is REFUSED, not executed and not
ignored. Ignoring it would be worse than refusing: the caller would believe it
had been honoured.

THE PRINCIPAL IS THE FRAME'S. Not the argument's. If an argument names a
different one, neither side silently wins -- that is principal_override_refused.
Silently preferring the frame would train callers to pass a principal that does
nothing, and the first time someone reads that code they will assume it works.
"""
from __future__ import annotations

from . import capture as capture_mod

# Parameter names that would carry a query across the seam. Refused by name.
QUERY_PARAMS = ("query", "sparql", "q", "select", "construct", "ask")

# Argument keys that would name a principal in competition with the frame.
PRINCIPAL_PARAMS = ("user_id", "userId", "principal", "graph", "user")


def ok(**fields):
    return dict(ok=True, **fields)


def refuse(reason, because):
    return {"ok": False, "reason": reason, "because": because}


class Registry:
    """Loaded captures. Load failures are refusals, not exceptions on a request."""

    def __init__(self, captures=None, load_error=None):
        self.captures = {c.name: c for c in (captures or [])}
        self.load_error = load_error

    @classmethod
    def from_dir(cls, directory):
        try:
            return cls(capture_mod.load_dir(directory))
        except capture_mod.CaptureError as e:
            # A registry that failed to load must not look like an empty one.
            # `functions` returning [] would read as "nothing captured yet",
            # which is the wrong thing to believe when a capture was rejected
            # for reaching a model at request time.
            return cls(load_error=(e.reason, e.because))

    def get(self, name):
        return self.captures.get(name)


def frame_principal(context):
    """The only principal. Missing, empty or non-string is context_user_required."""
    if not isinstance(context, dict):
        return None, refuse("context_user_required",
                            "this seam takes one standard-form ContextFrame; got %s"
                            % type(context).__name__)
    user = context.get("userId")
    if not isinstance(user, str) or not user.strip():
        return None, refuse("context_user_required",
                            "the frame must carry a non-empty string userId. There is no "
                            "anonymous mode and no optional-for-admin escape on this seam")
    return user.strip(), None


def _guard_params(params, user):
    """Refuse a query across the seam, and a competing principal. In that order."""
    for key in QUERY_PARAMS:
        if key in params:
            return refuse(
                "raw_query_refused",
                "a %r parameter would send a query across this seam. An agent that can send "
                "arbitrary SPARQL can un-scope a user; the only queries that run here are "
                "captured functions" % key,
            )

    for key in PRINCIPAL_PARAMS:
        if key in params and str(params[key]) != user:
            return refuse(
                "principal_override_refused",
                "argument %s=%r disagrees with the frame's userId=%r. The frame is the only "
                "principal, and neither side wins silently" % (key, params[key], user),
            )
    return None


def call(registry, context, function, event_id, at=None, params=None, execute=None):
    """Invoke a captured lambda. Returns an envelope and raises nothing.

    `execute(query, bindings)` is the store call -- the CPCP/SPARQL hop that is
    INSIDE the function rather than in the caller's hands. It is injected so the
    seam can be exercised without a live oxigraph; production passes the real one.
    """
    params = params or {}

    user, bad = frame_principal(context)
    if bad:
        return bad

    if registry.load_error:
        reason, because = registry.load_error
        return refuse(reason, because)

    guard = _guard_params(params, user)
    if guard:
        return guard

    cap = registry.get(function)
    if cap is None:
        return refuse(
            "unknown_function",
            "no capture named %r. Known: %s" % (function, ", ".join(sorted(registry.captures)) or "none"),
        )

    if event_id is None or (isinstance(event_id, str) and not event_id.strip()):
        return refuse("event_id_required",
                      "a capture answers for one event-specific id; none was given")

    # A call that does not name a position is asking for "as of now", and the
    # ANSWER RECORDS WHICH NOW IT GOT. Without that a result cannot be
    # re-checked, and an unreproducible retrieval is a fresh guess wearing a
    # captured function's name.
    position = at if at is not None else cap.verified_at

    # user_id is bound on EVERY execution, including for captures that do not
    # interpolate it. An unscoped public lookup ignores it; the frame still
    # required the id, and the binding is not conditional on the body.
    bindings = {"user_id": user, "id": event_id}

    if execute is None:
        return refuse(
            "graph_unreachable",
            "no store binding was supplied to this call; the capture was not run, and "
            "reporting zero rows would be indistinguishable from a real empty answer",
        )

    try:
        rows = execute(cap.query, bindings)
    except Exception as e:  # noqa: BLE001 - never-raise is the contract
        return refuse("graph_unreachable", "%s: %s" % (type(e).__name__, e))

    return ok(function=cap.name, id=event_id, at=position, scoped=cap.scoped, result=rows)


def functions(registry, context):
    """List loadable captures. Requires userId so the seam is uniform."""
    _user, bad = frame_principal(context)
    if bad:
        return bad

    if registry.load_error:
        reason, because = registry.load_error
        return refuse(reason, because)

    return ok(functions=[c.to_row() for c in registry.captures.values()])


def replay(registry, context, function, execute=None):
    """Re-run a capture's recorded examples at their recorded position.

    ok only if EVERY example reproduces. This is what makes a capture a captured
    function rather than a note about one, and it is also where the curated
    retraining set of TowardsSlms.md comes from: an example that stops
    reproducing is a labelled failure with a known cause and a known position.
    """
    _user, bad = frame_principal(context)
    if bad:
        return bad

    if registry.load_error:
        reason, because = registry.load_error
        return refuse(reason, because)

    cap = registry.get(function)
    if cap is None:
        return refuse("unknown_function", "no capture named %r" % function)

    if execute is None:
        return refuse("capture_unreproducible",
                      "replay needs a store binding; a replay that runs nothing passes "
                      "without checking anything")

    failures = []
    for i, example in enumerate(cap.examples):
        bindings = {"user_id": example.get("user_id", "replay"), "id": example["id"]}
        try:
            got = execute(cap.query, bindings, at=cap.verified_at)
        except Exception as e:  # noqa: BLE001
            failures.append({"example": i, "id": example["id"], "error": "%s: %s" % (type(e).__name__, e)})
            continue
        if got != example["expected"]:
            failures.append({"example": i, "id": example["id"],
                             "expected": example["expected"], "got": got})

    if failures:
        return refuse(
            "capture_unreproducible",
            "%d of %d recorded examples did not reproduce at %s: %s"
            % (len(failures), len(cap.examples), cap.verified_at, failures),
        )

    return ok(function=cap.name, at=cap.verified_at, examples=len(cap.examples), reproduced=True)
