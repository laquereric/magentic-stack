#!/usr/bin/env python3
"""A document that states a count must agree with the code it counts.

THE INCIDENT. Two CANONICAL.md files existed in parallel, both plausible, and
they disagreed on a fact: one said Ui::Catalog "ships seven" task kinds, the
other "ships all twelve". It was settled by counting the kinds. Nothing caught
it -- it surfaced only because an unrelated merge happened to be blocked by the
untracked file, and the wrong copy would otherwise have been as readable as the
right one.

That is the shape this gate covers, and only that shape: a claim in prose whose
truth is a number the tree already knows. Not general assertions embedded in
documents -- a mini-language in the docs would be a new thing to maintain, and
unused generality rots. A short, named list of load-bearing counts instead.

FAILS CLOSED twice over. A claim whose pattern no longer matches any document
is an error, not a pass: it means the doc was reworded and this gate silently
stopped checking anything. And a counter that finds zero is an error, because a
count of zero agreeing with a doc that says zero proves nothing about either.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]

errors: list[str] = []


# ---- the counters: what the TREE says -------------------------------------

def count_task_kinds() -> int:
    """Task kinds Ui::Catalog actually ships."""
    p = ROOT / "gems/rails-osi-level-8/lib/rails_osi_level_8/ui/catalog.rb"
    return len(re.findall(r'"kind"\s*=>\s*"', p.read_text(encoding="utf-8"))) if p.is_file() else 0


def count_pod_containers() -> int:
    """Services in the pod compose.

    Top-level `configs:` entries are NOT containers. The milvus embedded-etcd
    config sits at the same indentation as a service and reads as one; counting
    it gives 15 where the pod has 14.
    """
    p = ROOT / "runtimes/mind-pod/app/extract/compose.yml"
    if not p.is_file():
        return 0
    text = p.read_text(encoding="utf-8")
    body = text.split("\nconfigs:", 1)[0]
    body = body.split("\nvolumes:", 1)[0]
    return len(re.findall(r"^  ([a-z][\w-]*):\s*$", body, re.M))


def count_adrs() -> int:
    d = ROOT / "docs/adr"
    return len([p for p in d.glob("*.md") if re.match(r"^\d{4}-", p.name)]) if d.is_dir() else 0


# ---- the claims: what the DOCS say ----------------------------------------
#
# Each row: a document, a regex whose group(1) is the number, how to read that
# number, and the counter it must equal. Keep this list short and load-bearing;
# a claim nobody would act on is not worth a gate.

WORDS = {"seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
         "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16}


def as_number(raw: str) -> int | None:
    raw = raw.strip().lower()
    if raw.isdigit():
        return int(raw)
    return WORDS.get(raw)


CLAIMS = [
    ("docs/architecture/CANONICAL.md",
     r"Live `Ui::Catalog` ships\s+(?:all\s+)?(\w+)",
     count_task_kinds,
     "the task kinds Ui::Catalog ships"),
    ("README.md",
     r"the\s+([\w-]+)-container\s+MIND centered Pod",
     count_pod_containers,
     "services in the pod compose"),
    ("README.md",
     r"the\s+([\w-]+)-container Pod built around the MIND container",
     count_pod_containers,
     "services in the pod compose"),
    ("docs/architecture/OVERVIEW.md",
     r"## The governance pod — (\d+)-container MIND Pod",
     count_pod_containers,
     "services in the pod compose"),
    ("docs/README.md",
     r"the (\d+)-container MIND Pod",
     count_pod_containers,
     "services in the pod compose"),
]


def main() -> int:
    populated, _pop = emit_population(len(CLAIMS), skipped_reason="no claims registered")
    if not populated:
        return 1

    for rel, pattern, counter, what in CLAIMS:
        path = ROOT / rel
        if not path.is_file():
            errors.append("%s is missing; the claim it carried is unchecked" % rel)
            continue

        m = re.search(pattern, path.read_text(encoding="utf-8"))
        if not m:
            # The doc was reworded and this gate quietly stopped checking.
            errors.append(
                "%s no longer matches the pattern for %s. The claim may still be there in "
                "different words -- which means this gate stopped checking and said nothing. "
                "Fix the pattern or drop the row." % (rel, what)
            )
            continue

        claimed = as_number(m.group(1))
        if claimed is None:
            errors.append("%s: cannot read %r as a number (%s)" % (rel, m.group(1), what))
            continue

        actual = counter()
        if actual == 0:
            errors.append(
                "the counter for %s found zero. A doc agreeing with zero proves nothing "
                "about either side" % what
            )
            continue

        if claimed != actual:
            errors.append(
                "%s says %d, the tree says %d (%s). One CANONICAL.md said seven task kinds "
                "while another said twelve; this is that, caught early"
                % (rel, claimed, actual, what)
            )
        else:
            print("  ok %s: %d == %d (%s)" % (rel, claimed, actual, what))

    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("doc counts: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1
    print("doc counts: OK (%d claims)" % len(CLAIMS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
