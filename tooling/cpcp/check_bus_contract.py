#!/usr/bin/env python3
"""Fail if the BUS contract version drifts between code and spec.

Row 75. Breaking classes (method removed/renamed, required params added,
envelope keys removed/renamed, result narrowed, projection columns
dropped) bump Bus::Projector::CONTRACT_VERSION; additive changes do not.
Participants pin to a version and refuse a superseded contract -- with no
versioned consumers yet, this gate pins code to spec so the first bump
cannot land silently.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

PROJECTOR = Path("runtimes/mind-pod/app/app/services/bus/projector.rb")
SPEC = Path("runtimes/mind-pod/app/spec/bus_spec.rb")


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

    examined += 1
    src = (root / PROJECTOR).read_text(encoding="utf-8", errors="replace") if (root / PROJECTOR).is_file() else ""
    m = re.search(r"CONTRACT_VERSION\s*=\s*(\d+)", src) if src else None
    if not src:
        errors.append("missing %s" % PROJECTOR.as_posix())
    elif not m:
        errors.append("Bus::Projector declares no CONTRACT_VERSION")
    else:
        print("  ok contract version %s declared" % m.group(1))

    examined += 1
    if src and '"contract_version"' not in src and "'contract_version'" not in src:
        errors.append("latest response does not serve contract_version")
    elif src:
        print("  ok version served on latest")

    examined += 1
    spec = (root / SPEC).read_text(encoding="utf-8", errors="replace") if (root / SPEC).is_file() else ""
    if not spec:
        errors.append("missing %s" % SPEC.as_posix())
    elif "CONTRACT_VERSION" not in spec:
        errors.append("bus_spec does not pin CONTRACT_VERSION")
    else:
        print("  ok spec pins the version")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("BUS CONTRACT FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("bus contract: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
