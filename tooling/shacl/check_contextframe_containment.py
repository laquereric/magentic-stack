#!/usr/bin/env python3
"""Fail if ContextFrame / Meaning / Clarification are peers or reuse p8 Frame.

Gap 107. Containment: Meaning inContextFrame minCount 1; Clarification
inMeaning minCount 1. New topic https://w3id.org/cpcp/osi8/contextframe#.
Not profile-11. Not p8:FrameChange / frameName / frameDigest.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

SRC = Path("gems/shapes-level-8/bundles/contextframe.shacl.ttl")
P11 = Path("gems/shapes-level-8/bundles/profile-11-meaning.ttl")
NS = "https://w3id.org/cpcp/osi8/contextframe#"
FORBIDDEN = ("FrameChange", "frameName", "frameDigest", "PanelFrame", "osi.example")


def fail_empty_check_root():
    if "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return True
    return False


def root_from_env():
    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    return Path(raw)


def main():
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1
    try:
        nonempty = any(root.iterdir())
    except OSError as e:
        print("FAIL: CHECK_ROOT unreadable: %s" % e, file=sys.stderr)
        return 1
    if not nonempty:
        print("FAIL: empty CHECK_ROOT tree", file=sys.stderr)
        return 1

    errors = []
    examined = 0

    path = root / SRC
    examined += 1
    raw = path.read_text(encoding="utf-8") if path.is_file() else ""
    text = "\n".join(line.split("#", 1)[0] for line in raw.splitlines()) if raw else ""
    if not raw:
        errors.append("missing %s" % SRC.as_posix())
    else:
        print("  ok %s" % SRC.as_posix())

    examined += 1
    if NS not in raw:
        errors.append("shape namespace is not %s" % NS)
    else:
        print("  ok namespace %s" % NS)

    examined += 1
    for name in ("ContextFrameShape", "MeaningShape", "ClarificationShape"):
        if name not in text:
            errors.append("missing %s" % name)
    # CONTAINMENT SURVIVED THE AMENDMENT; the predicate changed.
    #
    # Gap 107 asserted containment as cf:inContextFrame / cf:inMeaning with
    # minCount 1 AND maxCount 1 -- a meaning belongs to exactly one frame.
    # MeaningActivations.md amends the maxCount: a meaning is ACTIVATED under
    # frames with a signed weight and may be activated under many.
    #
    # What this gate still defends is the half that did not change. A meaning
    # that names NO frame is unanchored, which is what gap 107 was written to
    # prevent, and an activation list with minCount 1 says that just as well as
    # a single-valued FK did. So: minCount 1 on the activation, and no maxCount
    # putting the tree back.
    for predicate, subject in (("cf:frameActivation", "Meaning"),
                               ("cf:meaningActivation", "Clarification")):
        if predicate not in text:
            errors.append("%s is not anchored (%s missing)" % (subject, predicate))
            continue
        window = text.split(predicate, 1)[-1][:200]
        if "sh:minCount 1" not in window:
            errors.append("%s is not anchored (%s minCount 1)" % (subject, predicate))
        if "sh:maxCount 1" in window:
            errors.append("%s activation is capped at one; MeaningActivations.md amends that maxCount" % subject)

    # The weight is the edge. A list of activations carrying no weight would be
    # a set of parents again, wearing a longer name.
    for shape in ("cf:FrameActivationShape", "cf:MeaningActivationShape"):
        if shape not in text:
            errors.append("missing %s" % shape)
    if "cf:weight" not in text:
        errors.append("activations carry no cf:weight; that is a parent list, not an activation")
    else:
        window = text.split("cf:weight", 1)[-1][:300]
        if "sh:minInclusive -1" not in window or "sh:maxInclusive 1" not in window:
            errors.append("cf:weight is not bounded to [-1, +1]")

    if not errors:
        print("  ok three shapes; activations anchored and weighted")

    examined += 1
    for bad in FORBIDDEN:
        if bad in text:
            errors.append("reuses forbidden name %s" % bad)
    if not any(bad in text for bad in FORBIDDEN):
        print("  ok no p8 Frame / PanelFrame / osi.example")

    examined += 1
    p11 = root / P11
    p11t = p11.read_text(encoding="utf-8") if p11.is_file() else ""
    if "ContextFrame" in p11t or "ClarificationShape" in p11t:
        errors.append("profile-11-meaning.ttl was extended; gap 107 forbids that")
    else:
        print("  ok profile-11 untouched")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("CONTEXTFRAME CONTAINMENT FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("contextframe containment: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
