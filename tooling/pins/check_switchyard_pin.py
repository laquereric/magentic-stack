#!/usr/bin/env python3
"""Fail if the Switchyard pin moves without a re-review, or the records drift.

ADR 0061. The originally accepted SHA lives in the ADR frontmatter
(accepted_pin). The live pin is pin.json pinned_revision. Gitlink must
equal that field. A populated submodule HEAD must equal it too.
pinned_revision may differ from accepted_pin only when reviews[] has a
row whose sha is the new pin, with at/by/looked_at/because filled.

A SHA that merely appears in the tree is not a review.

Empty CHECK_ROOT fails. 0 examined is not a pass.
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

ADR = Path("docs/adr/0061-switchyard-pre-alpha-pin-is-the-accepted-risk.md")
PIN = Path("upstreams/manifests/nemo-switchyard.pin.json")
QUOTE_PREALPHA = (
    "Switchyard is pre-alpha software that is evolving rapidly. "
    "The API and algorithms are expected to change significantly before we reach v1.0."
)
QUOTE_WARNING = "Experimental software. Not for production use."
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
ACCEPTED_RE = re.compile(r'^accepted_pin:\s*"([0-9a-f]{40})"', re.M)
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


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


def git(args, cwd):
    try:
        return subprocess.run(
            ["git", *args], cwd=str(cwd), capture_output=True, text=True, timeout=30
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def gitlink_sha(root: Path, sub: str):
    r = git(["ls-tree", "HEAD", sub], root)
    if r is None or r.returncode != 0:
        return None, (r.stderr.strip() if r else "git missing")
    for tok in r.stdout.split():
        if SHA_RE.match(tok):
            return tok, None
    return None, "no 40-hex in ls-tree: %s" % r.stdout.strip()[:80]


def working_head(root: Path, sub: str):
    path = root / sub
    # Unpopulated submodule: no src/.git. `git -C src` would walk up to
    # the parent repo and report the stack HEAD -- that is not drift.
    if not (path / ".git").exists():
        return None, "unpopulated"
    top = git(["rev-parse", "--show-toplevel"], path)
    if top is None or top.returncode != 0:
        return None, "unpopulated"
    toplevel = Path(top.stdout.strip()).resolve()
    if toplevel == root.resolve():
        return None, "unpopulated"
    r = git(["rev-parse", "HEAD"], path)
    if r is None or r.returncode != 0:
        return None, "unpopulated"
    sha = (r.stdout or "").strip()
    if SHA_RE.match(sha):
        return sha, None
    return None, "unpopulated"


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
    adr_path = root / ADR
    adr = adr_path.read_text(encoding="utf-8", errors="replace") if adr_path.is_file() else ""
    if not adr:
        errors.append("missing %s" % ADR.as_posix())
    else:
        print("  ok %s" % ADR.as_posix())
    if QUOTE_PREALPHA not in adr:
        errors.append("ADR 0061 does not quote upstream pre-alpha sentence verbatim")
    else:
        print("  ok quoted pre-alpha sentence")
    if QUOTE_WARNING not in adr:
        errors.append("ADR 0061 does not quote 'Experimental software. Not for production use.'")
    else:
        print("  ok quoted production warning")
    if "v0.2.0-rc2" not in adr or "64" not in adr:
        errors.append("ADR 0061 does not record 64 commits past v0.2.0-rc2")
    if "0038" not in adr:
        errors.append("ADR 0061 does not keep ADR 0038 (no fork)")
    if "0050" not in adr:
        errors.append("ADR 0061 does not name 0050 as the consume decision")
    am = ACCEPTED_RE.search(adr)
    accepted = am.group(1) if am else ""
    if not accepted:
        errors.append("ADR 0061 missing accepted_pin 40-hex in frontmatter")
    else:
        print("  ok accepted_pin %s" % accepted)

    examined += 1
    pin_path = root / PIN
    pin = None
    if not pin_path.is_file():
        errors.append("missing %s" % PIN.as_posix())
    else:
        try:
            pin = json.loads(pin_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append("unparseable pin.json: %s" % e)
            pin = None
        else:
            print("  ok %s" % PIN.as_posix())
    live = str((pin or {}).get("pinned_revision") or "")
    if not SHA_RE.match(live):
        errors.append("pin.json pinned_revision is not 40-hex, got %r" % live)
    else:
        print("  ok live pin %s" % live)
    sub = str((pin or {}).get("submodule_path") or "").strip()
    if not sub:
        errors.append("pin.json submodule_path missing or empty")
    else:
        print("  ok submodule_path from pin.json")
    if (pin or {}).get("fork") is not False:
        errors.append("pin.json fork must be false (ADR 0038)")

    examined += 1
    reviews = (pin or {}).get("reviews")
    if reviews is None:
        reviews = []
    elif not isinstance(reviews, list):
        errors.append("pin.json reviews must be a list")
        reviews = []
    if accepted and live and live == accepted:
        print("  ok live pin is the originally accepted SHA; reviews not required")
    elif accepted and live:
        hits = [r for r in reviews if isinstance(r, dict) and r.get("sha") == live]
        if not hits:
            errors.append(
                "pin moved to %s without a reviews[] row for that sha "
                "(accepted_pin remains %s)" % (live, accepted)
            )
        else:
            rev = hits[-1]
            for field in ("from_sha", "at", "by", "looked_at", "because"):
                val = (rev.get(field) or "").strip() if isinstance(rev.get(field), str) else ""
                if field in ("from_sha",) and not SHA_RE.match(val):
                    errors.append("review for %s missing 40-hex %s" % (live, field))
                elif field == "at" and not DATE_RE.match(val):
                    errors.append("review for %s at= must be YYYY-MM-DD" % live)
                elif field in ("by", "looked_at", "because") and not val:
                    errors.append("review for %s has empty %s" % (live, field))
            if SHA_RE.match(str(rev.get("from_sha") or "")) and not errors:
                print("  ok re-review for %s" % live)

    examined += 1
    if not sub:
        errors.append("cannot read gitlink: no submodule_path")
    else:
        gl, gl_err = gitlink_sha(root, sub)
        if gl is None:
            errors.append("cannot read gitlink for %s: %s" % (sub, gl_err))
        elif live and gl != live:
            errors.append("gitlink %s != pin.json pinned_revision %s (record drift)" % (gl, live))
        else:
            print("  ok gitlink %s matches pin.json" % gl)

    examined += 1
    if not sub:
        errors.append("cannot check working tree: no submodule_path")
    else:
        head, head_why = working_head(root, sub)
        if head is None:
            print("  ok working tree %s (%s; not a pin move)" % (sub, head_why))
        elif live and head != live:
            errors.append(
                "working-tree HEAD %s != pin.json %s (checkout drift, not a recorded move)"
                % (head, live)
            )
        else:
            print("  ok working-tree HEAD %s" % head)

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("SWITCHYARD PIN FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("switchyard pin: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
