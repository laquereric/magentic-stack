"""MIND cognition, expressed in NOOA (NVIDIA Object-Oriented Agents).

MIND *hosts NOOA as-published* (upstreams/nooa/src, pinned). The agent is an
ordinary Python object: fields are state, the docstring is the prompt, the typed
return is the contract, and the `...` body is the LLM-driven loop. MIND produces
ONLY a bounded, typed Effect *proposal* of domain state; BACK commits proposals
through /_cpcp. Domain state is written by BACK and BACKJOB (ADR 0056), not by
MIND.

MIND's SQLite is the third kind of state (ADR 0057): ephemeral
nondeterministic inference, not a private copy of application state, not
metadata. DB_PATH binds it (ADR 0051); unset, NOOA stays in-memory. The bound
file currently lives on the named volume `mind-nooa-data` (survives restart,
dies on `down -v`). Whether that volume matches "ephemeral" is not
established — do not treat the file as the pod's record. Nothing in it is
shared truth; only an admitted proposal is.
"""
from __future__ import annotations
from pydantic import BaseModel, Field


class NoteInsight(BaseModel):
    """The closed shape MIND returns for BACK to validate + commit."""
    title: str
    body: str
    note_count: int = Field(ge=0)


class BoardReading(BaseModel):
    """The closed shape MIND returns for ONE board state.

    Typed, so what comes back is checkable before anything is stored. A free-text
    answer would have to be parsed, and parsing an LLM is how a proposal becomes
    a finding without anyone deciding that it should.
    """
    title: str
    body: str
    node_count: int = Field(ge=0)


class SessionReading(BaseModel):
    """The closed shape MIND returns for ONE state of ONE session.

    grounded_in is the generation the reading was made at. It is required and
    it is not decorative: two readings of a session are comparable only if
    each says which state it read, and a reading that cannot name its ground
    is a claim about nothing.
    """
    title: str
    body: str
    grounded_in: int = Field(ge=0)
    row_count: int = Field(ge=0)


def _storage():
    """Bind NOOA's embedded SQLite when DB_PATH names one (ADR 0051).

    Unset is not an error and not a guess: it keeps NOOA's own default, an
    in-memory store, which is exactly MIND's behaviour before this binding
    existed. Choosing a path here instead would put a database somewhere nobody
    asked for and lose it on the next recreate.

    NOOA holds a per-database session lock, so two MINDs pointed at one file get
    SessionAlreadyActiveError rather than two writers.
    """
    import os
    db_path = os.environ.get("DB_PATH", "").strip()
    if not db_path:
        return None
    from nooa.storage import SQLiteStorageManager
    return SQLiteStorageManager(db_path=db_path)


def build_agent(llm):
    """Construct the NOOA cognition agent bound to `llm` (always SWITCH)."""
    from nooa import Agent  # NOOA, run as-published

    class MindCognition(Agent, llm=llm):
        """You are MIND, a governed cognition step. You are given a bounded
        preview of ONE session, pulled by BACK over /_cpcp. You return a typed
        proposal. BACK validates and commits it. You do not write domain state;
        BACK and BACKJOB do.

        HOW YOU SEE THE WORLD. You do not connect to GRAPH. You do not issue
        SPARQL. BACK already queried for you; the rows you receive are the
        preview. You have no write path: proposing is the only way anything
        you produce can become part of what the pod knows.

        WHAT YOUR OWN MEMORY IS, AND IS NOT. You may carry inference memory
        across turns. That store is YOURS: it is nondeterministic inference
        state, not application state and not metadata. Nothing in it is true
        of the pod merely because you remember it. Shared truth is what BACK
        has admitted. Do not treat a recollection as evidence, and do not
        report one as though BACK had accepted it -- if it matters, ground it
        in the rows you were given this time, or propose it and let BACK
        decide. A memory you cannot ground is a lead, not a fact.

        WHAT YOU WERE GIVEN. The rows are a bounded preview of one session
        at one generation. Say which generation you read (grounded_in). Do
        not describe rows you were not shown. If the rows are empty, say so
        plainly -- that is the honest reading of a session with nothing in
        it, not a reason to invent contents.

        WHAT OTHERS CAN ASK OF ME. The harness keeps each reading and the
        Python I wrote that cycle, and serves them to operators over a
        pod-internal seam. That changes nothing about proposing: a served
        reading is still a lead, not a fact, and nothing I remember or
        wrote is true of the pod until BACK admits it.

        THE STANDING REFUSAL. Propose; never assert. Your output is a
        proposal that BACK may commit, and committing it makes it durable
        rather than true."""

        async def summarize(self, notes: list[dict]) -> NoteInsight:
            """Summarize the notes into a single insight note."""
            ...

        async def read_board(self, digest: str, nodes: list[dict]) -> BoardReading:
            """Read this board and say what it is FOR.

            `nodes` is a bounded preview of ONE board state -- component kinds and
            titles, pulled by reference from the graph at `digest`. Say what the
            board is doing and what stands out: which columns carry work, what is
            unaccepted, what is refused. Do not invent cards you were not shown
            and do not describe UI mechanics. One short paragraph.
            """
            ...

        async def read_session(self, session_iri: str, generation: int,
                               rows: list[dict]) -> SessionReading:
            """Read ONE state of ONE session and say what is going on in it.

            `rows` is a bounded preview BACK already pulled for this session at
            `generation`. You did not query; you were given these rows. Say what
            the session is doing, what has been proposed in it, and what stands
            out. Quote `generation` back as grounded_in -- it is the only thing
            that makes this reading comparable to the next one.

            If the rows show nothing worth remarking on, say so plainly. An empty
            preview honestly described is worth more than an interesting reading of
            a session that was not there. One short paragraph.
            """
            ...

    # storage=None is NOOA's own default, so the unbound case needs no branch.
    return MindCognition(storage=_storage())
