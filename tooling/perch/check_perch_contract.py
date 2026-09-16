#!/usr/bin/env python3
"""The Perch CID fragment must describe the projection that actually runs.

A contract maintained BESIDE the code is a memo. This repo has already paid
for that once: two CANONICAL.md files, both plausible, disagreeing about
whether Ui::Catalog shipped seven task kinds or twelve, settled by counting
the kinds. So this compares .cpcp/cid/perch.json against the live declaration
in the initializer and the closed refusal set in the gem, and fails when they
disagree -- in EITHER direction, because the contract drifting and the code
drifting are the same defect wearing different clothes.

FAILS CLOSED three ways. A missing fragment is an error. An operation declared
in code and absent from the contract is an error (an undeclared wire surface).
An operation in the contract that no longer exists in code is also an error --
that one is worse, because it reads as a promise.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
FRAGMENT = ROOT / ".cpcp/cid/perch.json"
PACKAGE = ROOT / ".cpcp/package.json"
INIT = ROOT / "runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"
SEAM = ROOT / "runtimes/mind-pod/app/lib/perch_seam.rb"
BINDING = ROOT / "runtimes/mind-pod/app/lib/actor_binding.rb"
REFUSALS = ROOT / "gems/vv-perch/lib/vv/perch/refusals.rb"

# operation "perch.x", direction: :pull, params: %w[a b],
OPERATION = re.compile(
    r'operation\s+"(perch\.[\w.]+)"\s*,\s*\n?\s*direction:\s*:(\w+)'
    r'(?:\s*,\s*params:\s*%w\[([^\]]*)\])?',
    re.M,
)

errors: list[str] = []


def declared_in_code() -> dict:
    text = INIT.read_text(encoding="utf-8")
    out = {}
    for name, direction, params in OPERATION.findall(text):
        out[name] = {
            "direction": direction.upper(),
            "params": params.split() if params else [],
        }
    return out


def main() -> int:
    for path in (FRAGMENT, PACKAGE, INIT, REFUSALS, BINDING, SEAM):
        if not path.is_file():
            print("FAIL: missing %s" % path.relative_to(ROOT), file=sys.stderr)
            emit_population(0)
            return 1

    fragment = json.loads(FRAGMENT.read_text(encoding="utf-8"))
    package = json.loads(PACKAGE.read_text(encoding="utf-8"))
    named = (package.get("cid_fragments") or {}).get("perch")
    if named != ".cpcp/cid/perch.json":
        errors.append(
            "package.json cid_fragments.perch is %r; a fragment nobody points at is a memo"
            % named
        )
    if "tooling/perch/check_perch_contract.py" not in (package.get("gates") or []):
        errors.append("package.json gates does not name check_perch_contract.py")
    contract_ops = {o["name"]: o for o in fragment.get("operations", [])}
    code_ops = declared_in_code()

    populated, _ = emit_population(len(code_ops), skipped_reason="no perch operations declared")
    if not populated:
        return 1

    # Both directions. An operation missing from the contract is an undeclared
    # wire surface; one missing from the code is a promise nothing keeps.
    for name in sorted(set(code_ops) - set(contract_ops)):
        errors.append("%s is declared in the initializer and absent from the contract" % name)
    for name in sorted(set(contract_ops) - set(code_ops)):
        errors.append(
            "%s is in the contract and no longer declared in code; a contract that promises an "
            "operation nobody serves is worse than one that omits it" % name
        )

    for name in sorted(set(code_ops) & set(contract_ops)):
        code, doc = code_ops[name], contract_ops[name]
        if doc.get("direction") != code["direction"]:
            errors.append(
                "%s: contract says %s, code declares %s. Direction is not cosmetic -- PUSH is an "
                "admission and carries operationId" % (name, doc.get("direction"), code["direction"])
            )
        if sorted(doc.get("params", [])) != sorted(code["params"]):
            errors.append(
                "%s: contract params %s, code params %s"
                % (name, sorted(doc.get("params", [])), sorted(code["params"]))
            )
        if not doc.get("refusals") and doc.get("direction") is not None:
            errors.append(
                "%s declares no refusals; the reason is what a caller branches on, and an "
                "operation that cannot say how it says no is not specified" % name
            )

    # Identity is never a wire param. Established with the BPMN work and the
    # single most important property of this surface: a caller that can name
    # itself can be anyone.
    for name, doc in sorted(contract_ops.items()):
        if "actor_id" in doc.get("params", []):
            errors.append("%s declares actor_id as a wire param; identity comes from the bearer" % name)
    for name, code in sorted(code_ops.items()):
        if "actor_id" in code["params"]:
            errors.append("%s declares actor_id in code; identity comes from the bearer" % name)

    # Every PUSH is an admission and must be replayable.
    for name, code in sorted(code_ops.items()):
        if code["direction"] == "PUSH" and "operationId" not in code["params"]:
            errors.append("%s is PUSH without operationId; an admission that cannot replay is not idempotent" % name)

    # Refusals named in the contract exist. A vocabulary that drifts from the
    # closed set is how a caller ends up branching on a reason nothing emits.
    closed = set(re.findall(r'=\s*"([a-z_]+)"', REFUSALS.read_text(encoding="utf-8")))
    seam_text = SEAM.read_text(encoding="utf-8")
    seam_reasons = set(re.findall(r'fail_with\(\d+,\s*"([a-z_]+)"', seam_text))
    identity_reasons = set(fragment.get("refusal_vocabulary", {}).get("identity", {}))
    binding_reasons = set(re.findall(r'Error\.new\("([a-z_]+)"', BINDING.read_text(encoding="utf-8")))
    known = closed | seam_reasons | identity_reasons

    for name, doc in sorted(contract_ops.items()):
        for reason in doc.get("refusals", []):
            if reason not in known:
                errors.append(
                    "%s names refusal %r, which is in neither the gem's closed set nor the seam's "
                    "own reasons" % (name, reason)
                )

    # The seam's own reasons must all be described, or a caller meets one the
    # contract never mentioned.
    described = set(fragment.get("refusal_vocabulary", {}).get("seam", {}))
    for reason in sorted(seam_reasons - described):
        errors.append("the seam can answer %r and the contract does not describe it" % reason)

    # Identity is the shared ActorBinding, not a perch-only vocabulary. A
    # reason the binding can raise that the fragment never names is the same
    # defect as a seam reason with no description: the caller has nothing to
    # branch on except the string they happened to see once.
    for reason in sorted(binding_reasons - identity_reasons):
        errors.append(
            "ActorBinding can answer %r and the contract does not describe it" % reason
        )

    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("perch contract: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1

    print("perch contract: OK (%d operations, %d refusals described)"
          % (len(code_ops), len(described) + len(identity_reasons)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
