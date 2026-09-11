"""The Mind -> Switch clue. A HEADER, carrying no corpus content.

docs/architecture/TowardsSlms.md. ADR 0019 is explicit and it is not negotiable:

    Content-blind. Routing reads headers, never the body. A router that reads
    the prompt to decide where to send it has read the prompt.

    Pinning is a header (X-SwitchYard-Source: vendor:model), not the body's
    `model` field, so the routing decision does not depend on parsing the payload.

So "the PySparqlFun -> SLM path is done through clues sent Mind -> Switch" has
exactly one legal shape. X-SwitchYard-Source is the precedent to copy: a routing
fact expressed as a header precisely so the router never parses the body.

WHAT A CLUE MAY NAME: a task class, a capture id, a capability (`select`, not
`author`). All opaque to the switch.

WHAT IT MAY NOT CARRY: the customer id, the event text, the prompt, retrieved
chunks, or anything else that would make the routing decision depend on reading
the payload.

THE ASYMMETRY THAT MAKES THIS SAFE IN BOTH DIRECTIONS. Because the clue is opaque
to the switch, the switch cannot start making retrieval decisions with it.
Retrieval stays in rag and graph; generation stays on switch; ADR 0019's line
between them does not move because nothing here gives it a reason to.

WHY VALIDATION LIVES ON THE MIND SIDE. The switch is content-blind, which means
it is exactly the wrong place to ask "is this header content?" -- answering that
requires looking at what the value means. MIND knows what it is about to send and
can refuse to send it. A content-blind router cannot police content; it can only
avoid reading it.
"""
from __future__ import annotations

import re

HEADER = "X-Mind-Clue"

# The precedent, named so the shape is obvious to the next reader.
PIN_HEADER = "X-SwitchYard-Source"

# select chooses among captured functions. author discovers a new one and stays
# frontier-class. TowardsSlms.md: do not shrink the author, do not let the
# selector author.
CAPABILITIES = ("select", "author")

# A clue value is an opaque token: capability, then a task class or capture id.
# Deliberately narrow. Every character class admitted here is one a corpus
# fragment could hide in, and the grammar is the enforcement -- a validator that
# only looked for banned substrings would be a blocklist, and the interesting
# leaks are the ones nobody thought to ban.
TOKEN = re.compile(r"\A(select|author):([a-z0-9]([a-z0-9._-]{0,62}[a-z0-9])?)\Z")

MAX_LEN = 72


def refuse(reason, because):
    return {"ok": False, "reason": reason, "because": because}


def build(capability, task_class):
    """A clue value, or a refusal. Never a raise: this runs before a request."""
    if capability not in CAPABILITIES:
        return refuse("clue_capability_unknown",
                      "capability must be one of %s; got %r" % (", ".join(CAPABILITIES), capability))

    value = "%s:%s" % (capability, task_class)
    bad = validate(value)
    if bad:
        return bad
    return {"ok": True, "header": HEADER, "value": value}


def validate(value):
    """None when this value may be sent as a clue; a refusal otherwise."""
    if not isinstance(value, str) or not value:
        return refuse("clue_malformed", "a clue is a non-empty string")

    if len(value) > MAX_LEN:
        # Length is the crudest content signal and the most reliable one. A
        # task class is a short name; a prompt is not. Nothing legitimate needs
        # more than this, and anything that does is carrying something.
        return refuse(
            "clue_carries_content",
            "clue is %d characters (max %d). A task class is a short opaque name; a value "
            "this long is carrying payload, and ADR 0019 keeps the body out of routing"
            % (len(value), MAX_LEN),
        )

    if not TOKEN.match(value):
        return refuse(
            "clue_malformed",
            "a clue is `<select|author>:<task-class>` where the task class is lowercase "
            "alphanumeric with . _ or -. Got %r. The grammar IS the content rule: anything "
            "that does not fit it is not a name, and a blocklist would only catch the leaks "
            "someone already thought of" % value,
        )

    return None


def headers(capability, task_class, pin=None):
    """The full header set for a Mind -> Switch call, or a refusal.

    The clue rides BESIDE the pin, not inside the body, and neither is derived
    from the payload. That is the whole arrangement: two routing facts in
    headers, a body the router never opens.
    """
    made = build(capability, task_class)
    if not made.get("ok"):
        return made

    out = {HEADER: made["value"]}
    if pin:
        out[PIN_HEADER] = pin
    return {"ok": True, "headers": out}


def selected_function(clue_value, registry):
    """Resolve a selector's clue to a capture, or refuse. Never a fallback.

    TowardsSlms.md: an unknown name is a typed refusal, "never a fallback to
    'generate something reasonable'". A guessed function returns a DIFFERENT
    customer's plausible-looking history, which is worse than an admitted miss
    and much harder to notice.
    """
    bad = validate(clue_value)
    if bad:
        return bad

    capability, task_class = clue_value.split(":", 1)
    if capability != "select":
        return refuse(
            "selector_cannot_author",
            "clue capability is %r; only `select` resolves to a captured function. A selector "
            "that can author has become an author with a small model's judgement" % capability,
        )

    cap = registry.get(task_class)
    if cap is None:
        return refuse(
            "unknown_function",
            "selector named %r, which is not in the registry. Known: %s"
            % (task_class, ", ".join(sorted(registry.captures)) or "none"),
        )

    return {"ok": True, "function": cap.name, "scoped": cap.scoped}
