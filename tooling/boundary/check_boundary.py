#!/usr/bin/env python3
"""Gate 1 (Part A) - static ownership-boundary conformance for magentic-stack.

Enforces the tree's boundary rules STRUCTURALLY (no runtime pod required):
  - the three tiers exist (OWN IT / OFFICIAL / FOLLOW THEM);
  - every FOLLOW-THEM upstream is a PINNED SUBMODULE, not a fork/vendor;
  - every upstream pin record is complete (fork:false, pinned_revision set,
    submodule_path declared in .gitmodules);
  - upstreams/<name>/ holds only README.md beside its src/ submodule (no vendored source).

The full 5-container RUNTIME negative-test (MIND cannot reach a sink except via
BACK's /_cpcp) is intentionally OUT OF SCOPE here until runtimes/ land; that is
tracked as Gate 1 Part C in docs/plans/pilot-release-gates.md.
"""
from __future__ import annotations
import glob, json, os, sys
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
def rel(*p): return os.path.join(ROOT, *p)
def now(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

checks = []
def check(name, ok, detail=""):
    checks.append({"assertion": name, "ok": bool(ok), "detail": str(detail)})
    return bool(ok)

started = now()

# 1) the three tiers exist
tiers = {"OWN IT": ["grammar", "interfaces", "runtimes"],
         "OFFICIAL": ["apps", "plugins"],
         "FOLLOW THEM": ["upstreams"]}
for tier, dirs in tiers.items():
    for d in dirs:
        check(f"tier-dir-exists:{tier}:{d}", os.path.isdir(rel(d)), rel(d))

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

ok = all(c["ok"] for c in checks)
report = {
    "gate": "boundary-conformance",
    "status": "pass" if ok else "fail",
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
