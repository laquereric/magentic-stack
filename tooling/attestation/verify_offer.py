#!/usr/bin/env python3
"""Gate 3 - MagenticMarket offer attestation + policy digest (offline verifier).

Verifies an offer's CAPABILITY is bound to a POLICY by digest, WITHOUT inspecting
any underlying data/content (capability + policy are metadata only):

  - recompute policy_digest = sha256(canonical policy.json);
  - assert capability.policy_digest == that digest (the binding);
  - assert the capability declares no_content_inspection and a non-empty operation surface;
  - if an attestation bundle is provided (--attestation), verify OFFLINE that its
    in-toto subject digest == sha256(capability.json) and its predicate carries the
    same policy_digest (i.e. the signed statement binds the same capability<->policy).

Signing itself (Sigstore/DSSE via GitHub artifact attestation) is applied by the
workflow; this verifier is the machine-checkable, offline conformance check.
"""
from __future__ import annotations
import argparse, base64, hashlib, json, os, sys
from datetime import datetime, timezone

def now(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
def canon(obj): return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode()
def sha256_bytes(b): return hashlib.sha256(b).hexdigest()

ap = argparse.ArgumentParser()
ap.add_argument("--capability", required=True)
ap.add_argument("--policy", required=True)
ap.add_argument("--attestation", default=None)
ap.add_argument("--out", default="evidence/attestation.json")
a = ap.parse_args()

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from population import emit_population

if not os.path.isfile(a.capability) or not os.path.isfile(a.policy):
    emit_population(0, skipped_reason="capability or policy file missing")
    sys.exit(1)

checks = []
def check(name, ok, detail=""):
    checks.append({"assertion": name, "ok": bool(ok), "detail": str(detail)[:200]})
    print(("  ok  " if ok else "  FAIL") + f" {name} :: {str(detail)[:160]}")
    return bool(ok)

policy = json.load(open(a.policy))
cap = json.load(open(a.capability))
computed_policy_digest = "sha256:" + sha256_bytes(canon(policy))
cap_digest = sha256_bytes(open(a.capability, "rb").read())

check("policy-digest-binding", cap.get("policy_digest") == computed_policy_digest,
      f"cap={cap.get('policy_digest')} computed={computed_policy_digest}")
check("no-content-inspection", cap.get("no_content_inspection") is True and policy.get("data_inspection") is False,
      f"cap.no_content_inspection={cap.get('no_content_inspection')} policy.data_inspection={policy.get('data_inspection')}")
check("capability-surface-present", isinstance(cap.get("operations"), list) and len(cap["operations"]) > 0,
      f"{len(cap.get('operations', []))} operations")
check("policy-allows-declared-effects",
      all(o.get("operationId") in (policy.get("allowed_effects", []) + ["canonical.pull", "canonical.get", "methods.list"])
          for o in cap.get("operations", [])),
      "every advertised operation is a pull or a policy-allowed effect")

signed = False
if a.attestation and os.path.isfile(a.attestation):
    try:
        bundle = json.load(open(a.attestation))
        env = bundle.get("dsseEnvelope") or bundle.get("dsse_envelope") or {}
        payload = base64.b64decode(env["payload"]).decode()
        stmt = json.loads(payload)
        subj_sha = stmt["subject"][0]["digest"]["sha256"]
        pred_pd = (stmt.get("predicate") or {}).get("policy_digest")
        check("attestation-subject-matches-capability", subj_sha == cap_digest,
              f"subject={subj_sha[:16]} capability={cap_digest[:16]}")
        check("attestation-predicate-binds-policy", pred_pd == computed_policy_digest,
              f"predicate.policy_digest={pred_pd}")
        signed = True
    except Exception as e:
        check("attestation-parse", False, f"could not parse bundle: {e}")
else:
    print("  ..   (no attestation bundle supplied; binding verified without signature)")

_att = bool(a.attestation and os.path.isfile(a.attestation))
_ops = cap.get("operations") if isinstance(cap.get("operations"), list) else []
_populated, pop = emit_population(2, skipped=0 if _att else 1,
                                  skipped_reason="" if _att else "no attestation bundle")
pop["capability_operations"] = len(_ops)

ok = all(c["ok"] for c in checks)
report = {
    "gate": "attestation", "status": "pass" if ok else "fail",
    "population": pop,
    "subject": os.environ.get("GITHUB_SHA", "LOCAL"),
    "policy": "offer capability bound to policy digest, verified offline without content inspection",
    "started_at": now(), "finished_at": now(),
    "tool": "tooling/attestation/verify_offer.py",
    "assertions": checks,
    "digests": {"capability": "sha256:" + cap_digest, "policy": computed_policy_digest, "signed": signed},
}
os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
json.dump(report, open(a.out, "w"), indent=2)
fails = [c["assertion"] for c in checks if not c["ok"]]
if fails:
    print("GATE 3 FAIL: " + ", ".join(fails), file=sys.stderr); sys.exit(1)
print(f"offer attestation (Gate 3): OK ({len(checks)} checks; signed={signed})"); sys.exit(0)
