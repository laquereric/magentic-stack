#!/usr/bin/env python3
"""The registry SHA is written in four places; they must all say the same thing.

Review 2026-09-04a, gap 4.2. The cpcp_registry revision appears as:

  .cpcp/package.json                          .registry.sha
  .cpcp/public_cpcp/package.json              .registry.sha
  upstreams/manifests/cpcp_registry.pin.json  .pinned_revision
  the gitlink                                 upstreams/cpcp_registry/src

check_reversible_pins holds the manifest against the gitlink. The two .cpcp
copies were held by nothing, and were created deliberately with no gate behind
them -- the same shape as the pinned_revision/gitlink drift that
check_reversible_pins exists to catch, reintroduced one directory over.

FULL SHAS ONLY. An abbreviation that matches a prefix is not agreement: it is
two values that have not disagreed yet, and .cpcp/package.json says so itself
("Full SHA, never an abbreviation").

Empty CHECK_ROOT fails. Zero sites found is a failure, not a pass -- a rename
that made this checker look at nothing would otherwise read as compliance.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

FULL_SHA = re.compile(r"\A[0-9a-f]{40}\Z")

# THE PIN MANIFEST SAYS WHERE THE SUBMODULE IS; THIS DOES NOT.
#
# The submodule path was hardcoded here and check_boundary refused it, correctly:
# ADR 0020 makes adapters the sole path to upstreams, and it exempts
# upstreams/manifests because those are the repo's OWN pin records -- governance
# tooling reading them is the point of them. Reading submodule_path from the
# manifest obeys that, and is better anyway: the location is stated once, so a
# submodule that moves does not leave a checker quietly looking at nothing.
PIN_MANIFEST = "upstreams/manifests/cpcp_registry.pin.json"

# (file, dotted key path)
SITES = (
    (".cpcp/package.json", ("registry", "sha")),
    (".cpcp/public_cpcp/package.json", ("registry", "sha")),
    (PIN_MANIFEST, ("pinned_revision",)),
)


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


def dig(doc, path):
    cur = doc
    for key in path:
        if not isinstance(cur, dict) or key not in cur:
            return None
        cur = cur[key]
    return cur if isinstance(cur, str) else None


def submodule_path(root: Path):
    """Where the manifest says its submodule lives."""
    p = root / PIN_MANIFEST
    try:
        doc = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        return None, "%s is unreadable: %s" % (PIN_MANIFEST, e)
    path = doc.get("submodule_path")
    if not isinstance(path, str) or not path.strip():
        return None, "%s has no submodule_path, so the gitlink cannot be located" % PIN_MANIFEST
    return path.strip(), None


def gitlink_sha(root: Path, path: str):
    """The tree's own record of the submodule commit. Read from the index rather
    than from .gitmodules: .gitmodules says which repo, the gitlink says which
    revision, and the revision is the thing that drifts."""
    try:
        out = subprocess.run(
            ["git", "ls-files", "-s", path],
            cwd=str(root), capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError) as e:
        return None, "git ls-files failed: %s" % e
    if out.returncode != 0:
        return None, "git ls-files exit %d" % out.returncode
    for line in out.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[0] == "160000":
            return parts[1], None
    return None, "no gitlink at %s" % path


def main():
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1

    found = {}
    errors = []

    for rel, path in SITES:
        p = root / rel
        if not p.is_file():
            errors.append("%s is missing; the registry pin has to be written there" % rel)
            continue
        try:
            doc = json.loads(p.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            errors.append("%s is unreadable: %s" % (rel, e))
            continue
        value = dig(doc, path)
        if value is None:
            errors.append("%s has no %s" % (rel, ".".join(path)))
            continue
        if not FULL_SHA.match(value):
            errors.append(
                "%s %s = %r is not a full 40-character SHA; an abbreviation is not "
                "agreement, only two values that have not disagreed yet"
                % (rel, ".".join(path), value)
            )
            continue
        found[rel] = value

    path, err = submodule_path(root)
    if err:
        errors.append(err)
    else:
        sha, err = gitlink_sha(root, path)
        if err:
            errors.append("gitlink: %s" % err)
        elif not FULL_SHA.match(sha or ""):
            errors.append("gitlink %s = %r is not a full SHA" % (path, sha))
        else:
            found[path + " (gitlink)"] = sha

    ok_pop, _ = emit_population(len(found))
    if not ok_pop:
        return 1

    distinct = sorted(set(found.values()))
    if len(distinct) > 1:
        errors.append("the sites disagree: %s" % ", ".join(
            "%s=%s" % (k, v[:12]) for k, v in sorted(found.items())
        ))

    if errors:
        print("REGISTRY PIN AGREEMENT FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1

    print("registry pin agreement: OK (%d sites, all %s)"
          % (len(found), distinct[0][:12]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
