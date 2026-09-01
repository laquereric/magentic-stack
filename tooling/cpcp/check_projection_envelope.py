#!/usr/bin/env python3
"""Fail if projection fail-closed is still a reason allowlist.

Gap 93. failed_envelope? must treat any {ok:false} as failure. The
engine-limited SPARQL-star annotation DELETE is a CALL SITE
(rdf_star_annotation_delete), not a reason exemption.

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

STORABLE = Path("gems/vv-graph/lib/vv/graph/storable.rb")
IMMEDIATE = Path("gems/vv-graph/lib/vv/graph/publisher/immediate.rb")
REASON_ALLOWLIST = re.compile(
    r"failed_envelope\?.*?reason\s*==\s*:graph_unreachable",
    re.S,
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


def method_body(text: str, name: str):
    """Extract a `def name` ... next def/end at same indent, naive."""
    m = re.search(r"^([ \t]*)def (?:self\.)?%s\s*\(" % re.escape(name), text, re.M)
    if not m:
        return None
    indent = m.group(1)
    start = m.end()
    nxt = re.search(r"^%sdef |\n%sprivate\b|\n%sclass |\n%send\b" % (
        indent, indent, indent, indent), text[start:], re.M)
    end = start + nxt.start() if nxt else len(text)
    return text[m.start():end]


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

    storable = root / STORABLE
    examined += 1
    if not storable.is_file():
        errors.append("missing %s" % STORABLE.as_posix())
        st_text = ""
    else:
        st_text = storable.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % STORABLE.as_posix())

    examined += 1
    body = method_body(st_text, "failed_envelope?") if st_text else None
    if not body:
        errors.append("%s missing failed_envelope?" % STORABLE.as_posix())
    elif ":graph_unreachable" in body:
        errors.append(
            "%s failed_envelope? still allowlists :graph_unreachable (reason, not call site)"
            % STORABLE.as_posix()
        )
    elif "env[:ok] == false" not in body and "env[:ok]==false" not in body:
        errors.append("%s failed_envelope? does not fail on ok:false" % STORABLE.as_posix())
    else:
        print("  ok Storable.failed_envelope? is any ok:false")

    examined += 1
    if "def self.rdf_star_annotation_delete" in st_text:
        print("  ok rdf_star_annotation_delete call site exists")
    else:
        errors.append("%s missing rdf_star_annotation_delete" % STORABLE.as_posix())

    examined += 1
    if st_text.count("rdf_star_annotation_delete(") >= 4:
        print("  ok rdf_star_annotation_delete used at emit/retract sites")
    else:
        errors.append(
            "%s rdf_star_annotation_delete not used at the annotation DELETE sites"
            % STORABLE.as_posix()
        )

    imm = root / IMMEDIATE
    examined += 1
    if not imm.is_file():
        errors.append("missing %s" % IMMEDIATE.as_posix())
        im_text = ""
    else:
        im_text = imm.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % IMMEDIATE.as_posix())

    examined += 1
    if "Storable.failed_envelope?" in im_text:
        print("  ok Immediate delegates failed_envelope? to Storable")
    elif REASON_ALLOWLIST.search(im_text or ""):
        errors.append(
            "%s failed_envelope? still allowlists :graph_unreachable" % IMMEDIATE.as_posix()
        )
    else:
        errors.append(
            "%s does not use Storable.failed_envelope?" % IMMEDIATE.as_posix()
        )

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("PROJECTION ENVELOPE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("projection envelope: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
