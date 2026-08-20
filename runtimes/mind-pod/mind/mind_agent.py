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


def build_agent(llm):
    """Construct the NOOA cognition agent bound to `llm` (always SWITCH)."""
    from nooa import Agent  # NOOA, run as-published

    class MindCognition(Agent, llm=llm):
        """You are MIND, a governed cognition step. You are given a bounded preview
        of the BACK notes (Context, read by reference). Return ONE concise insight
        note that summarizes them for a human. You never persist anything; you only
        return a proposal for BACK to validate and commit."""

        async def summarize(self, notes: list[dict]) -> NoteInsight:
            """Summarize the notes into a single insight note."""
            ...

    return MindCognition()
