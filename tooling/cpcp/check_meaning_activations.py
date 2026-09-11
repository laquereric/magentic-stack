#!/usr/bin/env python3
"""Activations are weighted joins, and stay that way.

docs/architecture/MeaningActivations.md names the gates; these are them. Each
one guards a property that is cheap to lose by accident and expensive to
notice:

  NO PARENT FK        meanings.context_frame_id and clarifications.meaning_id
                      must not exist. Adding either re-introduces in-or-out
                      membership beside the weights, and then two answers to
                      "which frame is this under" disagree silently.

  NO SHORTCUT FK      clarifications.context_frame_id must not exist either. A
                      clarification reaches a frame only as Meaning through the
                      two joins; a shortcut would let it inhibit under a frame
                      its meaning does not activate.

  RANGE IN THE DB     the weight bound is a database trigger, not only a model
                      validation. update_column, an import, and the console all
                      bypass the model.

  UNIQUE PAIR         one row per (frame, meaning) and (meaning, clarification).
                      A second weight for a pair is a refusal, not a second
                      line to average.

  WALK EXCLUDES <= 0  the default walk is positive weights only. Zero is
                      present-and-inert and negative is inhibition; neither is
                      a child, and both stay readable on inspect.

Structural checks over source: a schema and a model say what they are without
a database to hand. The behavioural half -- that a -1.1 actually refuses -- is
exercised in the pod, where a real sqlite is.

FAILS CLOSED: no migration or no models is an error, not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
APP = ROOT / "runtimes/mind-pod/app"
MIGRATIONS = APP / "db/migrate"
MODELS = APP / "app/models"

FORBIDDEN_COLUMNS = (
    ("meanings", "context_frame_id", "parent FK; membership is the join row"),
    ("clarifications", "meaning_id", "parent FK; membership is the join row"),
    ("clarifications", "context_frame_id", "shortcut FK; a clarification reaches a frame only through its meaning"),
)

errors: list[str] = []


def main() -> int:
    if not MIGRATIONS.is_dir() or not MODELS.is_dir():
        print("FAIL: no app tree at %s" % APP, file=sys.stderr)
        emit_population(0)
        return 1

    migrations = sorted(MIGRATIONS.glob("*.rb"))
    models = sorted(MODELS.glob("*.rb"))
    populated, _pop = emit_population(len(migrations) + len(models),
                                      skipped_reason="no migrations and no models")
    if not populated:
        return 1

    migration_text = "\n".join(p.read_text(encoding="utf-8", errors="replace") for p in migrations)
    model_text = {p.stem: p.read_text(encoding="utf-8", errors="replace") for p in models}

    # The activation tables exist at all.
    for table in ("context_frame_meaning_weights", "meaning_clarification_weights"):
        if f"create_table :{table}" not in migration_text:
            errors.append(f"no migration creates {table}")

    # NO PARENT FK / NO SHORTCUT FK.
    for table, column, why in FORBIDDEN_COLUMNS:
        # A column arrives either in create_table or by add_column later.
        if re.search(rf"add_column\s+:{table},\s*:{column}\b", migration_text):
            errors.append(f"{table}.{column} is added by a migration -- {why}")
        block = re.search(rf"create_table :{table} do \|t\|(.*?)\n    end", migration_text, re.S)
        if block and re.search(rf"t\.(references|belongs_to)\s+:{column[:-3]}\b|t\.\w+\s+:{column}\b", block.group(1)):
            errors.append(f"{table}.{column} is created by a migration -- {why}")

    # RANGE IN THE DB: the bound survives code that bypasses the model.
    if "weight_out_of_range" not in migration_text:
        errors.append("no database-level weight bound; a model validation alone is bypassed by update_column")

    # UNIQUE PAIR.
    for name in ("index_cfmw_on_frame_and_meaning", "index_mcw_on_meaning_and_clarification"):
        if name not in migration_text:
            errors.append(f"missing unique index {name}; a pair could carry two weights")

    # The models say the same thing the schema does.
    for stem in ("context_frame_meaning_weight", "meaning_clarification_weight"):
        text = model_text.get(stem, "")
        if not text:
            errors.append(f"missing model {stem}.rb")
            continue
        if "weight_out_of_range" not in text:
            errors.append(f"{stem} does not refuse an out-of-range weight by name")
        if "activation_not_unique" not in text:
            errors.append(f"{stem} does not refuse a duplicate pair by name")

    # WALK EXCLUDES <= 0.
    for stem, method in (("context_frame", "activated_meanings"), ("meaning", "activated_clarifications")):
        text = model_text.get(stem, "")
        if not text:
            errors.append(f"missing model {stem}.rb")
            continue
        if method not in text:
            errors.append(f"{stem} has no {method}; the operative walk is derived, not stored")
        elif "weight > 0" not in text:
            errors.append(f"{stem}.{method} does not restrict to positive weights")

    # restrict_with_error: deleting a frame that still activates meanings is a
    # refusal, not a cascade that rewrites the net.
    for stem in ("context_frame", "meaning", "clarification"):
        text = model_text.get(stem, "")
        if text and "restrict_with_error" not in text:
            errors.append(f"{stem} does not restrict deletes; a cascade would rewrite the net silently")

    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("meaning activations: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1
    print("meaning activations: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
