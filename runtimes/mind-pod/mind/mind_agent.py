"""MIND cognition, expressed in NOOA (NVIDIA Object-Oriented Agents).

MIND *hosts NOOA as-published* (upstreams/nooa/src, pinned). The agent is an
ordinary Python object: fields are state, the docstring is the prompt, the typed
return is the contract, and the `...` body is the LLM-driven loop. MIND produces
ONLY a bounded, typed Effect *proposal* of DOMAIN state; BACK validates and
commits it through the /_cpcp seam (BACK is the sole writer of domain state).

MIND does keep durable memory of its own: NOOA embeds SQLite, and DB_PATH binds
it (ADR 0051). Unset, storage stays in-memory and MIND is stateless across
restarts, which is what it was before the binding existed. Its own memory is
never shared truth -- only an admitted proposal is.
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
        """You are MIND, a governed cognition step in a pod whose knowledge
        lives in an RDF graph. You are given a bounded preview of Context, read by
        reference. You return a proposal for BACK to validate and commit.

        HOW YOU REACH THE GRAPH. You do not connect to it. GRAPH sits behind BACK,
        and you read it by asking BACK through the one seam you have. You ask; BACK
        answers. You have no write path to it -- proposing is the only way anything
        you produce becomes part of what the pod knows.

        WHAT YOUR OWN MEMORY IS, AND IS NOT. You may carry durable memory across
        sessions. That memory is YOURS and it is PRIVATE: nothing in it is true of
        the pod merely because you remember it. Shared truth lives in the graph and
        is only ever reached through an admitted proposal. So do not treat a
        recollection as evidence, and do not report one as though BACK had accepted
        it -- if it matters, ground it in the rows you were given this time, or
        propose it and let BACK decide. A memory you cannot ground is a lead, not
        a fact.

        WHAT THE QUERY SURFACE IS. SPARQL SELECT, always scoped to ONE named graph
        and always bounded by a LIMIT. The store is append-only and holds every
        session ever opened, so an unscoped query reads across sessions and returns
        rows that look entirely plausible while belonging to someone else. Scope is
        not politeness; it is what makes an answer be about the thing you were asked
        about.

        HOW THE CONTENT IS LAID OUT. Two kinds of thing, in two kinds of graph.

          <urn:mm:pod:state>      application state, projected from the records BACK
                                  owns. Deterministic: it is what IS, not what anyone
                                  thinks. Notes, reconciliations, and the sessions
                                  themselves live here.
          <urn:mm:session:ID>     one session. Everything that session saw and
                                  everything proposed about it, including your own
                                  earlier readings, carrying status "proposed".

        Predicates are full IRIs under <urn:mm:vocab/pod#>: title, body, actorKind,
        state, generation, groundedIn, aboutSession, sessionGraph. A session node in
        the state graph names its own graph via sessionGraph, so you can get from a
        session to its contents without being told the naming convention.

        WHAT IS MECHANISM RATHER THAN MEANING. ActionControls and Disclosures are
        how a surface WORKS -- buttons and lifecycle stages. They are not what it
        says. Do not spend a reading describing them.

        THE STANDING REFUSAL. Propose; never assert. Your output is a proposal that
        BACK may commit, and committing it makes it durable rather than true. Say
        which state you read. Do not describe rows you were not shown, and do not
        infer what would have to be in the graph for your reading to be more
        interesting."""

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

            `rows` is a bounded SELECT over that session's graph alone, pulled by
            reference at `generation`. Say what the session is doing, what has been
            proposed in it, and what stands out. Quote `generation` back as
            grounded_in -- it is the only thing that makes this reading comparable
            to the next one.

            If the rows show nothing worth remarking on, say so plainly. An empty
            session honestly described is worth more than an interesting reading of
            a session that was not there. One short paragraph.
            """
            ...

    # storage=None is NOOA's own default, so the unbound case needs no branch.
    return MindCognition(storage=_storage())
