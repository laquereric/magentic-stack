#!/usr/bin/env python3
"""Step 4: shapes-application MAY depend on shapes-level-8.
shapes-level-8 MUST NOT depend on shapes-application.

Reads the two gemspecs. The key this checker reads is `forbidden`:
the list of dependencies from shapes-level-8 that name shapes-application
(add_dependency / add_runtime_dependency / add_development_dependency).

A planted `s.add_dependency "shapes-application"` in the level-8 gemspec
is the violation. An empty CHECK_ROOT (zero gemspecs) is the empty plant.

Does not move TTL, edit shapes, or touch config.shape_root.
"""
from __future__ import annotations
import json, os, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]

LEVEL8 = ROOT / "gems/shapes-level-8/shapes-level-8.gemspec"
APPLICATION = ROOT / "gems/shapes-application/shapes-application.gemspec"

# Captures the gem name from any of the three Bundler dependency forms.
DEP_RE = re.compile(
    r"""add(?:_runtime|_development)?_dependency\s*\(?\s*["']([^"']+)["']"""
)

FORBIDDEN_FROM_LEVEL8 = "shapes-application"


def deps_of(path: Path):
    if not path.is_file():
        return None
    found = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.lstrip()
        if stripped.startswith("#"):
            continue
        code = stripped.split("#", 1)[0]
        found.extend(DEP_RE.findall(code))
    return found


def main(_argv):
    level8_deps = deps_of(LEVEL8)
    app_deps = deps_of(APPLICATION)
    found = (0 if level8_deps is None else 1) + (0 if app_deps is None else 1)
    populated, _pop = emit_population(
        found, skipped_reason="expected shape gemspecs missing"
    )
    if not populated:
        return 1

    missing = []
    if level8_deps is None:
        missing.append(str(LEVEL8.relative_to(ROOT) if ROOT in LEVEL8.parents else LEVEL8))
    if app_deps is None:
        missing.append(str(APPLICATION.relative_to(ROOT) if ROOT in APPLICATION.parents else APPLICATION))
    if missing:
        print("FAIL-CLOSED: missing expected gemspecs: %s" % missing, file=sys.stderr)
        return 1

    forbidden = [d for d in level8_deps if d == FORBIDDEN_FROM_LEVEL8]
    report = {
        "level8_depends_on": level8_deps,
        "application_depends_on": app_deps,
        "forbidden": forbidden,  # THE KEY THE CHECKER READS
    }
    print("deps", json.dumps(report, sort_keys=True))
    if forbidden:
        print(
            "SHAPE GEM DEPS FAIL: shapes-level-8 depends on %s (forbidden direction)"
            % forbidden,
            file=sys.stderr,
        )
        return 1
    print("shape gem deps: OK (application -> level-8 allowed; reverse absent)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
