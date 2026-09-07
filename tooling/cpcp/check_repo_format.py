#!/usr/bin/env python3
"""This repo's .cpcp/ manifests conform to the format the contract publishes.

The checker is not ours. It lives in the contract home and arrives here as the
vendored submodule ADR 0020 governs.

So this is a wrapper, and it exists for one reason: sweep discovers
tooling/**/check_*.py, and the upstream file is check-repo-format.py with a
hyphen. Thirteen .cpcp manifests across five repos were held by nothing but
somebody remembering to run that script by hand, which is the same shape as the
pin drift check_reversible_pins exists to catch. Running it from the submodule
rather than from a copy means the version enforcing the format is the version
this repo pinned -- and check_reversible_pins already holds that gitlink against
the pin record, so the two gates compose: one proves the pin is what we claim,
the other proves we conform to it.

The submodule's location is NOT hardcoded. ADR 0020 makes gems/adapters/ the
sole path to upstreams and the boundary gate enforces it -- correctly, on the
first draft of this file. The path is read from the pin record instead
(.submodule_path), which is both the rule's exemption and the better answer:
the pin manifest already declares where the tree lives, so a moved submodule
changes one file rather than two that must be kept in step.

A missing submodule is ROT, not a skip: the manifests would be claiming
conformance to a contract not present to check them against.

Empty CHECK_ROOT fails.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

PIN_REL = os.path.join("upstreams", "manifests",
                       "coordination-protocol-contract-package.pin.json")
CHECKER_SUFFIX = os.path.join("tooling", "check-repo-format.py")


def main():
    raw = os.environ.get("CHECK_ROOT")
    if raw is not None and not str(raw).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return 1
    root = Path(raw) if raw else Path(__file__).resolve().parents[2]
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1

    pin = root / PIN_REL
    if not pin.is_file():
        print("FAIL: %s is missing; there is no pin record saying where the "
              "contract tree lives." % PIN_REL, file=sys.stderr)
        return 1
    try:
        submodule_path = json.loads(pin.read_text(encoding="utf-8"))["submodule_path"]
    except (ValueError, KeyError) as e:
        print("FAIL: %s has no readable submodule_path: %s" % (PIN_REL, e),
              file=sys.stderr)
        return 1

    checker = root / submodule_path / CHECKER_SUFFIX
    if not checker.is_file():
        print("FAIL: %s is missing. The submodule named by %s is not checked "
              "out, so the contract this repo's manifests cite cannot check "
              "them. Run `git submodule update --init` -- this is rot, not a "
              "skip." % (checker.relative_to(root), PIN_REL), file=sys.stderr)
        return 1

    manifests = sorted((root / ".cpcp").rglob("package.json")) if (root / ".cpcp").is_dir() else []
    ok_pop, _ = emit_population(len(manifests))
    if not ok_pop:
        return 1

    out = subprocess.run([sys.executable, str(checker), str(root)],
                         capture_output=True, text=True)
    sys.stdout.write(out.stdout)
    sys.stderr.write(out.stderr)
    return out.returncode


if __name__ == "__main__":
    sys.exit(main())
