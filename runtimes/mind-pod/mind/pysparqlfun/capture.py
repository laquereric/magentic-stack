"""A capture: the expensive question, answered once, in a form that can be re-checked.

docs/architecture/SparqlFun.md. A PySparqlFun is not a template you hand
bindings to. It is a named, deterministic function that takes an event-specific
id and returns the context, with the CPCP call INSIDE it -- the caller supplies
an id and a frame and nothing else.

WHAT A CAPTURE HAS TO CARRY, and why each part is load-bearing:

  name            what the selector names later (TowardsSlms.md). A closed set
                  of these is the whole reason a small model can do the job.
  query           the body. Never crosses the seam; callers name functions.
  scoped          whether this function's answer is per-principal.
  examples        (id, expected) pairs, each with the corpus position they were
                  verified at. Without these a capture cannot be replayed, and a
                  capture that cannot be replayed is a guess wearing a name.
  verified_at     the journal position the examples were checked against.
  captured_by     who did the expensive reasoning. NOOA, normally.

DETERMINISM IS IN (id, corpus_state), NOT IN WALL-CLOCK. The support case forbids
the stronger reading: the third call MUST see calls one and two, which the second
could not. So a capture promises that the same id at the same JOURNAL POSITION
returns the same rows in the same order -- and that position is recorded on every
answer, because a result that cannot say what it was computed against cannot be
re-checked.

TWO THINGS ARE REFUSED AT LOAD, NOT AT REQUEST TIME:

  a scoped function whose body never mentions user_id. If it loaded, every
  request would silently return another principal's rows, and the failure would
  look like data rather than like a bug.

  a capture that calls a model at request time. That is not a capture -- it is
  the thing capture was supposed to replace, wearing its name.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

# Ways a capture body could reach a model at request time. Checked as text
# because the body is data, not imported code -- there is nothing to introspect,
# and a capture that gets its sampling in past this list is a gap to close here
# rather than a reason to trust the list less.
SAMPLING_MARKERS = (
    "switch", "completion", "chat/completions", "llm", "openai", "anthropic",
    "sample(", "temperature", "max_tokens",
)

# The binding every scoped query must interpolate. SparqlFun.md: a template
# marked scoped that does not mention user_id "fails at load, not at request
# time".
USER_BINDING = re.compile(r"\?user_id\b|\$\{user_id\}|%\(user_id\)|\{\{\s*user_id\s*\}\}")


class CaptureError(Exception):
    """Raised only during LOAD. Never on a request path."""

    def __init__(self, reason, because):
        super().__init__(because)
        self.reason = reason
        self.because = because


class Capture:
    __slots__ = ("name", "query", "scoped", "examples", "verified_at",
                 "captured_by", "description", "source")

    def __init__(self, name, query, scoped, examples, verified_at,
                 captured_by, description="", source=None):
        self.name = name
        self.query = query
        self.scoped = bool(scoped)
        self.examples = examples
        self.verified_at = verified_at
        self.captured_by = captured_by
        self.description = description
        self.source = source

    @classmethod
    def from_dict(cls, data, source=None):
        missing = [k for k in ("name", "query", "examples", "verified_at", "captured_by")
                   if not data.get(k)]
        if missing:
            raise CaptureError(
                "capture_incomplete",
                "capture %s is missing %s; a capture that cannot name what it is or prove it "
                "ran is not a capture" % (source or "<inline>", ", ".join(missing)),
            )

        capture = cls(
            name=data["name"],
            query=data["query"],
            scoped=data.get("scoped", True),
            examples=data["examples"],
            verified_at=data["verified_at"],
            captured_by=data["captured_by"],
            description=data.get("description", ""),
            source=source,
        )
        capture.validate()
        return capture

    def validate(self):
        """Load-time refusals. Raises CaptureError; never returns a bad capture."""
        body = self.query

        if self.scoped and not USER_BINDING.search(body):
            raise CaptureError(
                "scoped_without_user_binding",
                "capture %r is marked scoped and never interpolates user_id. Loading it would "
                "mean every request silently answers for whichever principal the query happens "
                "to select, and that failure looks like data rather than like a bug" % self.name,
            )

        lowered = body.lower()
        hits = [m for m in SAMPLING_MARKERS if m in lowered]
        if hits:
            raise CaptureError(
                "sampling_inside_capture",
                "capture %r reaches a model at request time (%s). A capture that calls an LLM "
                "is the thing capture was supposed to replace" % (self.name, ", ".join(hits)),
            )

        if not isinstance(self.examples, list) or not self.examples:
            raise CaptureError(
                "capture_unreproducible",
                "capture %r carries no examples, so nothing can ever re-check it" % self.name,
            )

        for i, example in enumerate(self.examples):
            if "id" not in example or "expected" not in example:
                raise CaptureError(
                    "capture_unreproducible",
                    "capture %r example %d needs an id and an expected result" % (self.name, i),
                )

    def to_row(self):
        """What sparqlfun.functions lists. Not the body: callers name functions."""
        return {
            "name": self.name,
            "scoped": self.scoped,
            "captured_by": self.captured_by,
            "verified_at": self.verified_at,
            "examples": len(self.examples),
            "description": self.description,
        }


def load_dir(directory):
    """Every .json capture under a directory, or a CaptureError naming the first bad one.

    FAILS CLOSED on the directory being absent: a registry that quietly holds
    nothing would make `sparqlfun.functions` return an empty list, which reads
    as "no captures exist yet" rather than "the captures did not load".
    """
    path = Path(directory)
    if not path.is_dir():
        raise CaptureError("registry_missing", "no capture directory at %s" % path)

    captures = []
    for f in sorted(path.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except ValueError as e:
            raise CaptureError("capture_incomplete", "%s does not parse: %s" % (f.name, e))
        captures.append(Capture.from_dict(data, source=str(f)))
    return captures
