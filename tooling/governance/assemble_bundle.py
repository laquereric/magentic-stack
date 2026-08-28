#!/usr/bin/env python3
"""Gate 6 - assemble the governance-evidence.v1 bundle from collected gate reports.

Aggregates the per-gate gate-report.v1 artifacts + upstream pin state (current +
rollback) + SBOM file digests into one governance-evidence.v1 bundle with a
deterministic bundle_digest. Signing (DSSE/provenance attestation) is applied by
the workflow as a best-effort step; the CryptoGraphic bundle_digest here makes the
bundle tamper-evident regardless.

release_ready = there is at least one gate AND no gate FAILED AND none was SKIPPED.
The assembler always exits 0 (it only assembles); the workflow's decision step
fails the release only on a real gate FAILURE.
"""
from __future__ import annotations
import argparse, glob, hashlib, json, os, sys
from datetime import datetime, timezone

def now(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

ap = argparse.ArgumentParser()
ap.add_argument("--evidence-dir", required=True)
ap.add_argument("--pins-dir", default="upstreams/manifests")
ap.add_argument("--sbom", action="append", default=[])
ap.add_argument("--out", required=True)
ap.add_argument("--release", default=None,
                help="tag this bundle is evidence FOR; defaults to GITHUB_REF_NAME on a tag run")
a = ap.parse_args()

# WHAT THE BUNDLE IS EVIDENCE *FOR*.
#
# subject is the commit, which is precise and immutable. It is not what anyone
# asks about. "Was v0.4.1 green?" needs the tag, and the tag was absent -- so the
# link from release to evidence lived outside the artifact, in a mapping that is
# neither immutable nor signed. Tags get deleted and re-cut; two were, on
# 2026-08-28, within hours of each other.
#
# Taken from GITHUB_REF_TYPE/GITHUB_REF_NAME rather than passed by the workflow,
# so it cannot disagree with what actually triggered the run. --release exists
# for local assembly and for tests.
release = a.release
if release is None and os.environ.get("GITHUB_REF_TYPE") == "tag":
    release = os.environ.get("GITHUB_REF_NAME")

# 1) collect gate reports; dedupe by gate, preferring the file named "<gate>.json"
by_gate = {}
for p in sorted(glob.glob(os.path.join(a.evidence_dir, "**", "*.json"), recursive=True)):
    try:
        d = json.load(open(p))
    except Exception:
        continue
    if not (isinstance(d, dict) and "gate" in d and "status" in d):
        continue
    g = d["gate"]
    fn = os.path.basename(p)
    if g not in by_gate or fn == f"{g}.json":
        by_gate[g] = {"gate": g, "status": d.get("status"), "policy": d.get("policy"), "source_file": fn}
gates = sorted(by_gate.values(), key=lambda x: x["gate"])

# 2) upstream pin state (current + rollback)
pins = []
for pf in sorted(glob.glob(os.path.join(a.pins_dir, "*.pin.json"))):
    d = json.load(open(pf))
    pins.append({"name": d.get("name"), "source": d.get("source"),
                 "pinned_revision": d.get("pinned_revision"),
                 "rollback_target": d.get("rollback_target"), "fork": d.get("fork")})

# 3) SBOM file digests
sboms = []
for s in a.sbom:
    if os.path.isfile(s):
        fmt = "cyclonedx" if ("cdx" in s or "cyclonedx" in s) else "spdx" if "spdx" in s else "unknown"
        sboms.append({"file": os.path.basename(s), "format": fmt, "sha256": sha256_file(s)})

failures = [g["gate"] for g in gates if g["status"] == "fail"]
skipped = [g["gate"] for g in gates if g["status"] == "skipped"]
release_ready = bool(gates) and not failures and not skipped

core = {"schema": "governance-evidence.v1", "subject": os.environ.get("GITHUB_SHA", "LOCAL"),
        "release": release,
        "gates": gates, "pins": pins, "sboms": sboms}
digest = hashlib.sha256(json.dumps(core, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
bundle = dict(core)
bundle.update({"created_at": now(), "gate_failures": failures, "gates_skipped": skipped,
               "release_ready": release_ready, "bundle_digest": "sha256:" + digest})

json.dump(bundle, open(a.out, "w"), indent=2)
print(json.dumps(bundle, indent=2))
print(f"RELEASE_READY={release_ready} FAILURES={failures} SKIPPED={skipped}")
print(f"RELEASE={release or '(not a tag run)'} SUBJECT={core['subject']}")

# 4) emit a gate-report.v1 for Gate 6 itself (assembly succeeded => pass)
os.makedirs("evidence", exist_ok=True)
gate6 = {"gate": "governance-evidence", "status": "pass", "subject": core["subject"],
         "policy": "assemble+digest governance-evidence.v1 (signing best-effort; release_ready gates on all-pass)",
         "started_at": now(), "finished_at": now(), "tool": "tooling/governance/assemble_bundle.py",
         "assertions": [{"gates": len(gates)}, {"release_ready": release_ready}, {"release": release}],
         "digests": {"bundle": bundle["bundle_digest"]}}
json.dump(gate6, open("evidence/governance-evidence.json", "w"), indent=2)
sys.exit(0)
