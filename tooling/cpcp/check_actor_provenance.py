#!/usr/bin/env python3
"""Fail if the substrate can name an actor the caller did not prove.

plan_proven_actor.md, S2. G13 said "ADR 0040 unenforced (no proven actor)",
which describes an ABSENCE. The defect was worse than an absence and this gate
holds both halves of it.

RULE A -- NO FALLBACK TO A CONSTANT. profile9/mutations.rb wrote

    "actorCid" => params["actorCid"].to_s.empty? ? Graph.j1_actor_cid : ...

and pulls.rb did the same inside a `capability` that also said
canCommitEffect. Graph.j1_actor_cid is the constant
"cid:actor:governance-steward". So a request with no actor produced a
well-formed, shape-valid ledger row asserting a governance steward acted.
A MISSING actor is visible and refusable. A DEFAULTED one is a false statement
in a governance ledger, written by the substrate, and nothing looks wrong.

RULE B -- READS AND WRITES ASK THE SAME QUESTION. Pulls.journey_list always
required the actor and refused unless it resolved. The write path required
predecessorCid, predecessorDigest, eventKind, aciaDocumentDigest and
tokenSetDigest -- and not the actor. You had to prove who you were to look and
not to act. Any file that takes caller params and records an actor must
require_cid! that actor.

Scope is lib code only. A spec may legitimately pass the seeded actor as a
literal; what must never happen is the SERVER substituting one.

Empty CHECK_ROOT fails. 0 files examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SCAN_PREFIXES = ("gems/", "runtimes/", "tooling/")
SKIP_DIRS = frozenset({".git", "vendor", "node_modules", ".bundle",
                       "__pycache__", "tmp", "log", ".venv"})

# The seeded constants an actor must never silently become.
SEEDED = ("j1_actor_cid", "ACTOR_CID")

# `"actorCid" => <something>` where <something> falls back to a seeded constant:
# a ternary on emptiness/presence, or an `||` default. Matched on one logical
# line, which is how both real instances were written.
FALLBACK = re.compile(
    r'"actorCid"\s*=>.*(?:\?|\|\|).*(?:' + "|".join(SEEDED) + r')'
)
# The same defect written the other way round: presence check first.
FALLBACK_PRESENT = re.compile(
    r'"actorCid"\s*=>\s*Request\.present\?\(.*\)\s*\?'
)

RECORDS_ACTOR = re.compile(r'"actorCid"\s*=>')
# Reading the actor straight out of caller params is the same exposure as
# recording one: journey_list does params["actorCid"] and must prove it.
USES_ACTOR_PARAM = re.compile(r'params\[\s*"actorCid"\s*\]')
TAKES_PARAMS = re.compile(r'Request\.closed!\(\s*params')
REQUIRES_ACTOR = re.compile(r'require_cid!\(\s*params\s*,\s*"actorCid"\s*\)')
DEF_LINE = re.compile(r'^\s*def\s+([A-Za-z_][\w?!]*)', re.M)


def def_blocks(text: str):
    """(name, body) per `def`, body running to the next `def` or EOF.

    Crude on purpose: a real Ruby parse is not worth a dependency here, and
    the question -- does THIS method prove the actor it handles -- is answered
    correctly by the span between one def and the next.
    """
    marks = [(m.start(), m.group(1)) for m in DEF_LINE.finditer(text)]
    for i, (start, name) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(text)
        yield name, text[start:end]


def fail(msg: str) -> int:
    print("ACTOR-PROVENANCE FAIL: %s" % msg, file=sys.stderr)
    return 1


def root_from_env():
    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    if not raw.strip():
        return None
    return Path(raw)


def lib_sources(root: Path):
    out = []
    for prefix in SCAN_PREFIXES:
        base = root / prefix
        if not base.is_dir():
            continue
        for p in base.rglob("*.rb"):
            rel = p.relative_to(root).as_posix()
            if any(part in SKIP_DIRS for part in p.relative_to(root).parts):
                continue
            # lib code only: a spec may name the seeded actor on purpose.
            if "/lib/" not in "/" + rel:
                continue
            out.append(p)
    return sorted(out)


def main() -> int:
    root = root_from_env()
    if root is None:
        return fail("empty CHECK_ROOT")
    if not root.is_dir():
        return fail("CHECK_ROOT is not a directory: %s" % root)

    files = lib_sources(root)
    errors = []
    examined = 0
    recording = 0

    for path in files:
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        if "actorCid" not in text:
            continue
        examined += 1

        for i, raw in enumerate(text.splitlines(), 1):
            line = raw.split("#", 1)[0]
            if not line.strip():
                continue
            if FALLBACK.search(line) or FALLBACK_PRESENT.search(line):
                errors.append(
                    "%s:%d actorCid falls back to a seeded constant. A request "
                    "with no actor would be recorded as one -- refuse instead: "
                    "%s" % (rel, i, line.strip()[:120])
                )

        # PER DEF, NOT PER FILE. This asked the question of the whole file, so
        # one require_cid! anywhere satisfied every recorder in it -- and
        # pulls.rb has two (journey_list and page_get). The plant proved it:
        # removing journey_list's requirement left page_get's behind and the
        # gate stayed green over a read path that no longer proved its actor.
        if TAKES_PARAMS.search(text):
            for name, block in def_blocks(text):
                if not RECORDS_ACTOR.search(block) and not USES_ACTOR_PARAM.search(block):
                    continue
                recording += 1
                if not REQUIRES_ACTOR.search(block):
                    errors.append(
                        "%s#%s takes an actorCid from caller params but never "
                        "require_cid!(params, \"actorCid\") -- reads refuse an "
                        "unproven actor and writes must too" % (rel, name)
                    )

    ok, _ = emit_population(
        examined, skipped=0,
        skipped_reason="",
    )
    print("  files naming actorCid: %d; of those, recording from params: %d"
          % (examined, recording))
    if not ok:
        return fail("no lib source names actorCid -- this gate is looking at nothing")
    # A gate that finds no request-handling file has lost its subject even if
    # the tree is full of matches; say so rather than pass.
    if recording == 0:
        return fail("no file both takes caller params and records an actorCid; "
                    "the symmetry rule has no subject")
    if errors:
        print("ACTOR-PROVENANCE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("actor provenance: OK (no seeded fallback; every recorder requires the actor)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
