#!/usr/bin/env python3
"""Fail if a canonical home is seeded by hand, or scoped by nothing.

ADR 0074 decision 5. G12 reads as an absence -- nobody has seeded overlay
journeys yet. The absence is real and it was never the problem. Two callers
already seeded `journeys` with two DIFFERENT idempotence keys:

    j1.rb:41                find_or_initialize_by(title:, primary_actor_id:)
    mind-pod/db/seeds.rb:22 find_or_create_by!(title:)

against no unique index on any natural key. Same table, two answers to "which
row is this", and neither was wrong against a constraint because there was no
constraint. The result depended on run order.

That is the shape ADR 0040's actor work turned out to have. G13 was not a
missing field, it was a DEFAULTED one. G12 was not a missing seeder, it was two
DISAGREEING ones -- and the disagreement was invisible because the schema had
no opinion. This gate is what stops a third.

RULE A -- ONE WAY IN. A canonical home row is written by Vv::Base::Seeder and
by nothing else. find_or_initialize_by / find_or_create_by against Journey,
Flow, FlowStep, InformationModel, InformationField or Actor outside the loader
is the defect returning, because each caller that writes its own upsert also
invents its own idea of identity.

RULE C -- THE STEP CID IS DERIVED. ADR 0074 decision 6: a step's CID is a
digest over (bundle_key, journey_key, flow_key, step_key), computed by
Vv::Base::StepCid and never written down. A `cid` column on flow_steps is a
second source of truth for an identity the natural keys already determine, and
it can drift from its own inputs -- rename a step_key, forget the backfill, and
the row asserts an identity nothing else agrees with. That is this ADR's own
Context in a new place: not a missing field, a field that can silently be wrong.

RULE B -- SCOPED BY SOMETHING. journeys, actors and information_models carry
bundle_key (decision 2). A unique index on one of them that does not include
bundle_key is a cross-application collision waiting: two applications each
seeding a "steward" and the second one losing. Children are NOT in this rule --
flows is unique on (journey_id, flow_key) and flow_steps on (flow_id, step_key),
and both inherit scope through their parent, which decision 2 says is correct.

Scope for Rule A is non-spec Ruby under the scanned prefixes. A spec may build
rows directly; what must never happen is a SEEDING PATH deciding for itself
what makes a row the same row.

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
                       "__pycache__", "tmp", "log", ".venv", "spec", "test"})

# The one file allowed to upsert a canonical home.
LOADER = "gems/vv-base/lib/vv/base/seeder.rb"

CANONICAL_MODELS = ("Journey", "Flow", "FlowStep", "InformationModel",
                    "InformationField", "Actor")
# The association spellings reach the same tables: journey.flows.find_or_...
CANONICAL_ASSOCIATIONS = ("flows", "steps", "fields")

UPSERT = r"(?:find_or_initialize_by|find_or_create_by!?)"

BY_MODEL = re.compile(
    r"(?:^|[^A-Za-z0-9_:])(?:::)?(?:Vv::Base::)?(" + "|".join(CANONICAL_MODELS) + r")\s*\.\s*" + UPSERT
)
BY_ASSOCIATION = re.compile(
    r"\.\s*(" + "|".join(CANONICAL_ASSOCIATIONS) + r")\s*\.\s*" + UPSERT
)

# Tables that carry bundle_key, and so must scope their uniques by it.
BUNDLE_SCOPED_TABLES = ("journeys", "actors", "information_models")
# `add_column :flow_steps, :cid` and a `t.string :cid` inside the table body.
ADD_CID_COLUMN = re.compile(r"add_column\s+:flow_steps\s*,\s*:cid\b")
CREATE_FLOW_STEPS = re.compile(r"create_table\s+:flow_steps\b")
TABLE_CID_COLUMN = re.compile(r"t\.\w+\s+:cid\b")

ADD_INDEX = re.compile(
    r"add_index\s+:(\w+)\s*,\s*(%i\[[^\]]*\]|\[[^\]]*\]|:\w+)([^\n]*)"
)
REMOVE_INDEX = re.compile(
    r"remove_index\s+:(\w+)\s*,\s*(%i\[[^\]]*\]|\[[^\]]*\]|:\w+)"
)


def fail(msg: str) -> int:
    print("SEED-CONTRACT FAIL: %s" % msg, file=sys.stderr)
    return 1


def fail_empty_check_root() -> bool:
    return "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip()


def root_from_env() -> Path:
    env = os.environ.get("CHECK_ROOT")
    if env:
        return Path(env).resolve()
    return Path(__file__).resolve().parents[2]


def ruby_sources(root: Path):
    for prefix in SCAN_PREFIXES:
        base = root / prefix
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if path.suffix not in (".rb", ".rake") and path.name != "seeds.rb":
                continue
            if not path.is_file():
                continue
            if any(part in SKIP_DIRS for part in path.relative_to(root).parts):
                continue
            yield path


def migration_dirs(root: Path):
    """Group migrations by the schema they belong to, filename-ordered.

    Rails applies a db/migrate directory in filename order, and that order is
    what decides the final index state. Grouping keeps two schemas that happen
    to share a migration filename from being replayed as one."""
    dirs: dict[str, list[Path]] = {}
    for prefix in SCAN_PREFIXES:
        base = root / prefix
        if not base.is_dir():
            continue
        for path in base.rglob("db/migrate/*.rb"):
            if path.is_file():
                key = path.parent.relative_to(root).as_posix()
                dirs.setdefault(key, []).append(path)
    return {k: sorted(v, key=lambda p: p.name) for k, v in dirs.items()}


def index_columns(cols: str) -> list[str]:
    if cols.startswith("%i["):
        return cols[3:-1].split()
    if cols.startswith("["):
        return [c.strip().lstrip(":").strip("\"'") for c in cols[1:-1].split(",") if c.strip()]
    return [cols.lstrip(":")]


def main() -> int:
    if fail_empty_check_root():
        return fail("empty CHECK_ROOT")
    root = root_from_env()

    errors = []
    examined = 0
    seeding_files = 0

    for path in ruby_sources(root):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        examined += 1
        if rel == LOADER:
            continue

        hits = []
        for lineno, line in enumerate(text.splitlines(), start=1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            m = BY_MODEL.search(line)
            if m:
                hits.append((lineno, m.group(1), stripped))
                continue
            m = BY_ASSOCIATION.search(line)
            if m:
                hits.append((lineno, m.group(1), stripped))

        if hits:
            seeding_files += 1
            for lineno, what, stripped in hits:
                errors.append(
                    "%s:%d upserts a canonical home (%s) outside %s -- "
                    "one way in, or identity is decided per caller again: %s"
                    % (rel, lineno, what, LOADER, stripped[:96])
                )

    # Rule B reads the FINAL state of each schema, not each migration in
    # isolation. A migration that adds a global unique is not a violation if a
    # later one drops it -- that is exactly how decision 2 lands, and a gate
    # that could not tell the difference would refuse its own ADR's migrations.
    #
    # Each db/migrate directory is a separate schema and is replayed on its
    # own: mind-pod carries its own copy of these tables, so an index present
    # in vv-base proves nothing about mind-pod's database.
    scoped_indexes = 0
    for migrate_dir, paths in sorted(migration_dirs(root).items()):
        state = {}          # (table, cols) -> (rel, lineno, columns)
        for path in paths:
            rel = path.relative_to(root).as_posix()
            text = path.read_text(encoding="utf-8", errors="replace")
            for lineno, line in enumerate(text.splitlines(), start=1):
                stripped = line.strip()
                if stripped.startswith("#"):
                    continue
                m = REMOVE_INDEX.search(line)
                if m:
                    table = m.group(1)
                    cols = tuple(index_columns(m.group(2)))
                    state.pop((table, cols), None)
                    continue
                m = ADD_INDEX.search(line)
                if not m:
                    continue
                table, cols, tail = m.group(1), m.group(2), m.group(3)
                if "unique" not in tail:
                    continue
                columns = tuple(index_columns(cols))
                state[(table, columns)] = (rel, lineno, columns)

        for path in paths:
            rel = path.relative_to(root).as_posix()
            text = path.read_text(encoding="utf-8", errors="replace")
            in_flow_steps = False
            for lineno, line in enumerate(text.splitlines(), start=1):
                stripped = line.strip()
                if stripped.startswith("#"):
                    continue
                if CREATE_FLOW_STEPS.search(line):
                    in_flow_steps = True
                elif in_flow_steps and stripped == "end":
                    in_flow_steps = False
                hit = ADD_CID_COLUMN.search(line) or (in_flow_steps and TABLE_CID_COLUMN.search(line))
                if hit:
                    errors.append(
                        "%s:%d adds a cid column to flow_steps -- decision 6 derives "
                        "the step CID from (bundle_key, journey_key, flow_key, "
                        "step_key); a stored one is a second source of truth that "
                        "can drift from its own inputs" % (rel, lineno)
                    )

        for (table, columns), (rel, lineno, _) in sorted(state.items()):
            if table not in BUNDLE_SCOPED_TABLES:
                continue
            if "bundle_key" in columns:
                scoped_indexes += 1
                continue
            errors.append(
                "%s:%d unique index on %s spans %s and not bundle_key, and "
                "nothing later drops it -- decision 2 scopes this table, and an "
                "unscoped unique collides across applications (schema: %s)"
                % (rel, lineno, table, list(columns), migrate_dir)
            )

    ok, _ = emit_population(examined, skipped=0, skipped_reason="")
    print("  ruby sources examined: %d; bundle-scoped unique indexes: %d"
          % (examined, scoped_indexes))
    if not ok:
        return fail("no ruby source examined -- this gate is looking at nothing")
    if scoped_indexes == 0:
        # Rule B with no subject is not a pass. If nothing scopes by bundle_key
        # the migrations have not landed, and Rule A alone is half the contract.
        return fail("no unique index on a bundle-scoped table includes "
                    "bundle_key -- decision 2 has not landed, so Rule B has "
                    "no subject")
    if errors:
        print("SEED-CONTRACT FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1

    print("seed contract: OK (canonical homes upserted only by the loader; "
          "every bundle-scoped unique includes bundle_key; step CID stays derived)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
