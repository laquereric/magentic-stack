#!/usr/bin/env python3
"""Gate 4 - reversible upstream pins.

Proves, for each pinned upstream, that:
  1. the manifest pinned_revision matches the committed submodule gitlink (no drift);
  2. pinned_revision resolves in the upstream and can be checked out (ADVANCE);
  3. rollback_target is set, resolves, and can be checked out (ROLLBACK);
  4. the ADVANCE -> ROLLBACK round-trip succeeds in an isolated clone.

Out of scope here (documented TODO = Gate 4 Part 2): SBOM/provenance generation
and running the CPCP contract against each pin (needs interfaces/adapters +
runtimes/). See docs/plans/pilot-release-gates.md.
"""
from __future__ import annotations
import glob, json, os, subprocess, sys, tempfile, shutil
from datetime import datetime, timezone

ROOT = os.environ.get("CHECK_ROOT") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
def now(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

checks = []
def check(name, ok, detail=""):
    checks.append({"assertion": name, "ok": bool(ok), "detail": str(detail)})
    return bool(ok)

def git(args, cwd, timeout=120):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=timeout)

def gitlink_sha(submodule_path):
    r = git(["ls-tree", "HEAD", submodule_path], cwd=ROOT)
    # "160000 commit <sha>\t<path>"
    for tok in r.stdout.split():
        if len(tok) == 40 and all(c in "0123456789abcdef" for c in tok):
            return tok
    return None

started = now()
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from population import emit_population
pins = sorted(glob.glob(os.path.join(ROOT, "upstreams", "manifests", "*.pin.json")))
populated, pop = emit_population(len(pins), skipped_reason="no *.pin.json under upstreams/manifests")
if not populated:
    print(json.dumps({"gate": "reversible-pins", "status": "fail", "population": pop}, indent=2))
    sys.exit(1)
check("upstream-pins-exist", len(pins) > 0, f"{len(pins)} pin file(s)")

for pf in pins:
    name = os.path.basename(pf).replace(".pin.json", "")
    d = json.load(open(pf))
    src = d.get("source", "")
    pinned = str(d.get("pinned_revision", ""))
    rollback = str(d.get("rollback_target", "") or "")
    sub = d.get("submodule_path", "")

    # 1) no drift: manifest pinned_revision == committed gitlink
    gl = gitlink_sha(sub)
    check(f"pin-gitlink-matches:{name}", gl == pinned, f"gitlink={gl} manifest={pinned}")
    # rollback must be recorded
    check(f"rollback-target-set:{name}", bool(rollback) and rollback != "PENDING", rollback)

    if not src or not pinned or not rollback:
        check(f"reversible-roundtrip:{name}", False, "missing src/pinned/rollback")
        continue

    work = tempfile.mkdtemp(prefix=f"pin-{name}-")
    try:
        git(["init", "-q"], cwd=work)
        git(["remote", "add", "origin", src], cwd=work)
        # ADVANCE: fetch + checkout the pinned candidate
        fa = git(["fetch", "--depth", "1", "origin", pinned], cwd=work)
        ca = git(["checkout", "-q", "FETCH_HEAD"], cwd=work) if fa.returncode == 0 else fa
        adv_head = git(["rev-parse", "HEAD"], cwd=work).stdout.strip() if ca.returncode == 0 else ""
        check(f"advance-checkout:{name}", adv_head == pinned,
              f"HEAD={adv_head} want={pinned} ({(fa.stderr or ca.stderr).strip()[:120]})")
        # ROLLBACK: fetch + checkout the rollback target
        fr = git(["fetch", "--depth", "1", "origin", rollback], cwd=work)
        cr = git(["checkout", "-q", "FETCH_HEAD"], cwd=work) if fr.returncode == 0 else fr
        rb_head = git(["rev-parse", "HEAD"], cwd=work).stdout.strip() if cr.returncode == 0 else ""
        check(f"rollback-checkout:{name}", rb_head == rollback,
              f"HEAD={rb_head} want={rollback} ({(fr.stderr or cr.stderr).strip()[:120]})")
        check(f"reversible-roundtrip:{name}", adv_head == pinned and rb_head == rollback,
              "advance then rollback both succeeded")
    finally:
        shutil.rmtree(work, ignore_errors=True)

ok = all(c["ok"] for c in checks)
report = {
    "gate": "reversible-pins",
    "status": "pass" if ok else "fail",
    "subject": os.environ.get("GITHUB_SHA", "LOCAL"),
    "policy": "advance to pinned_revision + roll back to rollback_target, no gitlink drift; SBOM/provenance + CPCP-contract = Part 2 (TODO)",
    "started_at": started, "finished_at": now(),
    "tool": "tooling/pins/check_reversible_pins.py",
    "assertions": checks, "digests": {},
    "population": pop,
}
os.makedirs(os.path.join(ROOT, "evidence"), exist_ok=True)
with open(os.path.join(ROOT, "evidence", "reversible-pins.json"), "w") as fh:
    json.dump(report, fh, indent=2)
print(json.dumps(report, indent=2))
fails = [c["assertion"] for c in checks if not c["ok"]]
if fails:
    print("REVERSIBLE-PINS FAIL: " + ", ".join(fails), file=sys.stderr); sys.exit(1)
print(f"reversible pins: OK ({len(checks)} checks)"); sys.exit(0)
