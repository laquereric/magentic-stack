"""PySparqlFun: captured questions, invoked by name.

docs/architecture/SparqlFun.md and docs/architecture/TowardsSlms.md.

A third support call should carry the first two. The corpus already holds them;
what is missing is that FINDING them is re-derived from scratch on every call.
NOOA does that work once and captures it here, and call three stops
rediscovering how to find calls one and two.

In-process under MIND, which already owns Python (ADR 0047). The separate
container the design defaults to needs that ADR amended -- a second Python
service -- and nothing in this package depends on which way that goes.
"""
from . import capture, seam, clue  # noqa: F401

__all__ = ["capture", "seam", "clue"]
