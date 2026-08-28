#!/usr/bin/env python3
"""Gate 1 (Part A) - static ownership-boundary conformance for magentic-stack.

Enforces the tree's boundary rules STRUCTURALLY (no runtime pod required):
  - the three tiers exist (OWN IT / OFFICIAL / FOLLOW THEM);
  - every FOLLOW-THEM upstream is a PINNED SUBMODULE, not a fork/vendor;
  - every upstream pin record is complete (fork:false, pinned_revision set,
    submodule_path declared in .gitmodules);
  - upstreams/<name>/ holds only README.md beside its src/ submodule (no vendored source).
  - ADR 0020: only gems/adapters/ references upstreams/ from source or build files.

The full 5-container RUNTIME negative-test (MIND cannot reach a sink except via
BACK's /_cpcp) is intentionally OUT OF SCOPE here until runtimes/ land; that is
tracked as Gate 1 Part C in docs/plans/pilot-release-gates.md.
"""
from __future__ import annotations
import ast, glob, json, os, sys
from datetime import datetime, timezone

ROOT = os.environ.get("CHECK_ROOT") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
def rel(*p): return os.path.join(ROOT, *p)
def now(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

checks = []
def check(name, ok, detail=""):
    checks.append({"assertion": name, "ok": bool(ok), "detail": str(detail)})
    return bool(ok)

started = now()

# 1) the three tiers exist
#
# OFFICIAL is OPTIONAL. apps/ and plugins/ were removed in the one-home-per-gem
# restructure, and this list still demanded them -- so Gate 1 Part A was failing
# on main for a tree that was correct. An empty tier is a fact about what is
# currently vendored, not a boundary violation. OWN IT and FOLLOW THEM stay
# required: a tree with no owned contract layer, or no pinned upstream tier, is
# a tree whose boundary means nothing.
REQUIRED_TIERS = {"OWN IT": ["grammar", "gems", "runtimes"],
                  "FOLLOW THEM": ["upstreams"]}
OPTIONAL_TIERS = {"OFFICIAL": ["apps", "plugins"]}
for tier, dirs in REQUIRED_TIERS.items():
    for d in dirs:
        check(f"tier-dir-exists:{tier}:{d}", os.path.isdir(rel(d)), rel(d))
for tier, dirs in OPTIONAL_TIERS.items():
    present = [d for d in dirs if os.path.isdir(rel(d))]
    check(f"tier-optional:{tier}", True,
          ", ".join(present) if present else "absent (nothing OFFICIAL vendored)")

# 2) .gitmodules submodule paths
submodule_paths = set()
gm = rel(".gitmodules")
if os.path.isfile(gm):
    for line in open(gm):
        s = line.strip()
        if s.startswith("path"):
            submodule_paths.add(s.split("=", 1)[1].strip())
check("gitmodules-present", os.path.isfile(gm), gm)

# 3) each upstream pin record complete + is a submodule + not forked
pins = sorted(glob.glob(rel("upstreams", "manifests", "*.pin.json")))
check("upstream-pins-exist", len(pins) > 0, f"{len(pins)} pin file(s)")
for pf in pins:
    name = os.path.basename(pf)
    try:
        d = json.load(open(pf))
    except Exception as e:
        check(f"pin-parse:{name}", False, e); continue
    rev = str(d.get("pinned_revision", ""))
    check(f"pin-revision-set:{name}", bool(rev) and rev != "PENDING", rev)
    check(f"pin-not-fork:{name}", d.get("fork") is False, d.get("fork"))
    sp = d.get("submodule_path", "")
    check(f"pin-submodule-declared:{name}", sp in submodule_paths, sp)

# 4) FOLLOW-THEM not vendored/forked: upstreams/<name>/ = README.md + src/ submodule only
updir = rel("upstreams")
for entry in sorted(os.listdir(updir)) if os.path.isdir(updir) else []:
    p = os.path.join(updir, entry)
    if entry == "manifests" or not os.path.isdir(p):
        continue
    stray = []
    for root, dirs, files in os.walk(p):
        if "src" in dirs:
            dirs.remove("src")  # the submodule checkout is opaque
        for f in files:
            rp = os.path.relpath(os.path.join(root, f), p)
            if rp != "README.md":
                stray.append(rp)
    check(f"upstream-not-forked:{entry}", not stray,
          ",".join(stray) if stray else "clean (README + src submodule only)")

# 5) ADR 0020 - gems/adapters/ is the ONLY code permitted to reach upstreams/.
#
# The rule existed as prose since ADR 0001 and nothing checked it. An
# import-boundary rule is what a fitness function should own: the damage is never
# the first import, it is the tenth, in ten files, after which 'what would
# re-pinning cost' has no answer short of reading everything.
#
# SCOPE, stated rather than implied. This scans SOURCE and BUILD files for a
# literal reference to the upstreams/ path. It does NOT catch an import by bare
# module name after sys.path has been rewritten elsewhere -- that is a second
# vector, and claiming otherwise would be the false confidence this gate exists
# to prevent. Docs and CI config are excluded deliberately: they cite the path
# legitimately, and a check that cries wolf on a README gets muted within a week.
CODE_SUFFIXES = ('.rb', '.py', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.rs', '.go', '.rake')
BUILD_NAMES = ('Gemfile', 'package.json', 'Cargo.toml', 'Dockerfile')
# Narrow and named: adapters is the sanctioned door, upstreams describes itself,
# and this file names the path it enforces.
ADAPTER_DIR = os.path.join('gems', 'adapters')
EXEMPT_PREFIXES = (ADAPTER_DIR, 'upstreams', os.path.join('tooling', 'boundary'))
SKIP_DIRS = {'.git', 'node_modules', '.venv', 'venv', 'vendor', 'dist', 'tmp', 'evidence', '.bundle'}
NEEDLE = 'upstreams/'
# upstreams/manifests holds the repo's OWN pin records. Governance tooling
# reading them is the point of them; it is not a reach into upstream source.
PIN_PATH = 'upstreams/manifests'

def _is_scanned(relpath):
    base = os.path.basename(relpath)
    return relpath.endswith(CODE_SUFFIXES) or base in BUILD_NAMES or base.endswith('.gemspec')

def _docstring_lines(text):
    # Bare string expressions -- module/class/function docstrings. A docstring
    # that says where NOOA lives is prose, not a reach across the boundary.
    # A string used as a real path is NOT one of these and still counts.
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return set()
    out = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant) \
                and isinstance(node.value.value, str):
            out.update(range(node.value.lineno, (node.value.end_lineno or node.value.lineno) + 1))
    return out


def _strip_comment(line):
    for marker in ('#', '//'):
        i = line.find(marker)
        if i != -1:
            line = line[:i]
    return line


_violations = []
_scanned_files = 0
for _root, _dirs, _files in os.walk(ROOT):
    _dirs[:] = [d for d in _dirs if d not in SKIP_DIRS]
    for _f in _files:
        _rp = os.path.relpath(os.path.join(_root, _f), ROOT)
        if _rp.startswith(EXEMPT_PREFIXES) or not _is_scanned(_rp):
            continue
        _scanned_files += 1
        try:
            _text = open(os.path.join(_root, _f), encoding='utf-8', errors='ignore').read()
        except OSError:
            continue
        _skip = _docstring_lines(_text) if _rp.endswith('.py') else set()
        for _n, _line in enumerate(_text.splitlines(), 1):
            if _n in _skip:
                continue
            _code = _strip_comment(_line)
            if NEEDLE in _code and PIN_PATH not in _code:
                _violations.append(_rp + ':' + str(_n))

check('adapters-sole-path-to-upstreams', not _violations,
      ', '.join(_violations[:10]) if _violations
      else 'clean (' + str(_scanned_files) + ' source/build files scanned; docs and CI config out of scope)')

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from population import emit_population
populated, pop = emit_population(_scanned_files, skipped_reason="non-source/non-build or exempt prefix")
if not populated:
    print(json.dumps({"gate": "boundary-conformance", "status": "fail", "population": pop}, indent=2))
    sys.exit(1)

ok = all(c["ok"] for c in checks)
report = {
    "gate": "boundary-conformance",
    "status": "pass" if ok else "fail",
    "population": pop,
    "subject": os.environ.get("GITHUB_SHA", "LOCAL"),
    "policy": "static ownership-boundary (OWN IT / OFFICIAL / FOLLOW THEM); runtime negative-test = Gate 1 Part C (TODO)",
    "started_at": started,
    "finished_at": now(),
    "tool": "tooling/boundary/check_boundary.py",
    "assertions": checks,
    "digests": {},
}
os.makedirs(rel("evidence"), exist_ok=True)
with open(rel("evidence", "boundary-static.json"), "w") as fh:
    json.dump(report, fh, indent=2)
print(json.dumps(report, indent=2))
fails = [c["assertion"] for c in checks if not c["ok"]]
if fails:
    print("BOUNDARY STATIC FAIL: " + ", ".join(fails), file=sys.stderr)
    sys.exit(1)
print(f"boundary static conformance: OK ({len(checks)} checks)")
sys.exit(0)
