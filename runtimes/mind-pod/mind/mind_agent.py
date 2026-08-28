"""MIND cognition, expressed in NOOA (NVIDIA Object-Oriented Agents).

MIND *hosts NOOA as-published* (upstreams/nooa/src, pinned). The agent is an
ordinary Python object: fields are state, the docstring is the prompt, the typed
return is the contract, and the `...` body is the LLM-driven loop. MIND produces
ONLY a bounded, typed Effect *proposal* -- it never writes to storage; BACK
validates and commits it through the /_cpcp seam (BACK is the sole writer).
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


def build_agent(llm):
    """Construct the NOOA cognition agent bound to `llm` (always SWITCH)."""
    from nooa import Agent  # NOOA, run as-published

    class MindCognition(Agent, llm=llm):
        """You are MIND, a governed cognition step in a pod whose knowledge
        lives in an RDF graph. You are given a bounded preview of Context, read by
        reference. You never persist anything; you only return a proposal for BACK
        to validate and commit.

        HOW YOU REACH THE GRAPH. You do not connect to it. GRAPH sits behind BACK,
        and you read it by asking BACK through the one seam you have. You ask; BACK
        answers. There is no second socket, and there is no write path for you at
        all -- proposing is the only way anything you produce becomes durable.

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

    return MindCognition()
