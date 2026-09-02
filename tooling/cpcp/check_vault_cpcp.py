#!/usr/bin/env python3
"""Fail if the vault CPCP contract loses a 0046 invariant.

Gap 50. Contract definition, not the REST migrate. Checks:

- methods are exactly put/list/get (none invented)
- config-admin is not allowlisted for get
- allowlist is before the store
- refusals are non-200 AND an envelope (row 49 KEEP BOTH)
- shape IRIs use w3id.org/cpcp/osi8/, not osi.example
- 0046 amendment 2 is decided (no TBD / not-yet-decided)
- vault is a decided-unbuilt seam, not live, not not-a-seam

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

CONTRACT = Path("tooling/cpcp/vault_cpcp.json")
SEAMS = Path("tooling/cpcp/seam_authority.json")
ADR = Path("docs/adr/0046-vault-is-not-the-config-ui.md")

METHODS = [
    "vault.secret.put",
    "vault.secret.list",
    "vault.secret.get",
]
NS = "https://w3id.org/cpcp/osi8/vault#"


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


def load_json(path: Path):
    if not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


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
    contract = load_json(root / CONTRACT)
    if contract is None:
        errors.append("missing %s" % CONTRACT.as_posix())
        contract = {}
    else:
        print("  ok %s" % CONTRACT.as_posix())

    examined += 1
    names = [m.get("name") for m in (contract.get("methods") or [])]
    if names != METHODS:
        errors.append("methods must be exactly %s, got %s" % (METHODS, names))
    else:
        print("  ok methods are put/list/get, none invented")

    examined += 1
    callers = (contract.get("allowlist") or {}).get("callers") or {}
    admin = list(callers.get("config-admin") or [])
    llm = list(callers.get("llm-plane") or [])
    if "vault.secret.get" in admin:
        errors.append("config-admin is allowlisted for vault.secret.get (read-back asymmetry)")
    elif sorted(admin) != sorted(["vault.secret.put", "vault.secret.list"]):
        errors.append("config-admin operations must be put+list, got %s" % admin)
    else:
        print("  ok config-admin cannot get")
    if "vault.secret.get" not in llm:
        errors.append("llm-plane must be allowlisted for vault.secret.get")
    elif "vault.secret.put" in llm:
        errors.append("llm-plane is allowlisted for put (not a needed operation)")
    else:
        print("  ok llm-plane get only")

    examined += 1
    if (contract.get("allowlist") or {}).get("keys_on") != "method":
        errors.append("allowlist must key on method")
    if contract.get("allowlist_before_store") is not True:
        errors.append("allowlist_before_store must be true (refusal ahead of the store)")
    else:
        print("  ok allowlist keys on method, before store")

    examined += 1
    if contract.get("never_raise_and_non_200") is not True:
        errors.append("never_raise_and_non_200 must be true (row 49 KEEP BOTH)")
    statuses = contract.get("refusal_http_status") or {}
    for reason, code in (
        ("vault_unauthenticated", 401),
        ("vault_not_allowlisted", 403),
        ("vault_secret_absent", 404),
        ("other_store_error", 400),
    ):
        if statuses.get(reason) != code:
            errors.append("refusal %s must be HTTP %s, got %s" % (reason, code, statuses.get(reason)))
        if statuses.get(reason) == 200:
            errors.append("refusal %s is HTTP 200 (the named hazard)" % reason)
    if 200 in statuses.values():
        errors.append("a refusal maps to HTTP 200")
    env = contract.get("envelope") or {}
    for key in ("ok", "reason", "because"):
        if key not in env:
            errors.append("envelope missing %s" % key)
    if statuses.get("vault_unauthenticated") == 401 and "ok" in env:
        print("  ok non-200 plus envelope")

    examined += 1
    if contract.get("pod_internal") is not True:
        errors.append("pod_internal must be true")
    if contract.get("no_default_caller_token") is not True:
        errors.append("no_default_caller_token must be true")
    if contract.get("fail_closed_at_boot") is not True:
        errors.append("fail_closed_at_boot must be true")
    auth = contract.get("auth") or {}
    if auth.get("in_params") is not False:
        errors.append("caller token must not travel in JSON-RPC params")
    else:
        print("  ok pod-internal, fail-closed boot, token not in params")

    examined += 1
    ns = contract.get("shape_namespace") or ""
    if not ns.startswith("https://w3id.org/cpcp/osi8/"):
        errors.append("shape_namespace must be w3id.org/cpcp/osi8/ (row 22), got %s" % ns)
    shapes = contract.get("shapes") or {}
    examined += 1
    if not shapes:
        errors.append("no shapes named")
    for key, iri in shapes.items():
        if "osi.example" in iri:
            errors.append("shape %s mints osi.example: %s" % (key, iri))
        elif not iri.startswith("https://w3id.org/cpcp/osi8/"):
            errors.append("shape %s is not under w3id.org/cpcp/osi8/: %s" % (key, iri))
    if "osi.example" in json.dumps(contract):
        errors.append("contract mentions osi.example")
    else:
        print("  ok shape IRIs under %s" % ns)

    examined += 1
    adr_path = root / ADR
    adr = adr_path.read_text(encoding="utf-8", errors="replace") if adr_path.is_file() else ""
    if not adr:
        errors.append("missing %s" % ADR.as_posix())
    else:
        print("  ok %s" % ADR.as_posix())
    if "not yet decided" in adr or "(TBD)" in adr:
        errors.append("0046 amendment 2 still says the contract is TBD / not yet decided")
    if "non-200" not in adr:
        errors.append("0046 does not say non-200 plus envelope is correct")
    if "ahead of the store" not in adr and "before the store" not in adr:
        errors.append("0046 does not say get refusal stays ahead of the store")
    if "https://osi.example" in adr:
        errors.append("0046 mints an osi.example IRI")
    if adr and "not yet decided" not in adr and "(TBD)" not in adr:
        print("  ok 0046 amendment 2 is decided")

    examined += 1
    seams = load_json(root / SEAMS) or {}
    live_ids = [r.get("id") for r in (seams.get("live") or [])]
    unbuilt_ids = [r.get("id") for r in (seams.get("decided_unbuilt") or [])]
    not_ids = [r.get("id") for r in (seams.get("not_a_seam") or [])]
    if "vault" in live_ids:
        errors.append("vault is live; this turn does not migrate REST to /_cpcp")
    if "vault" in not_ids:
        errors.append("vault is still not-a-seam; CPCP inbound is decided, so it is decided-unbuilt")
    if "vault" not in unbuilt_ids:
        errors.append("vault missing from decided_unbuilt")
    else:
        row = next(r for r in seams["decided_unbuilt"] if r.get("id") == "vault")
        if not (row.get("authoritative_for") or "").strip():
            errors.append("vault decided-unbuilt has empty authoritative_for")
        if row.get("domain_writer") is True:
            errors.append("vault must not be domain_writer")
        if row.get("served_by"):
            errors.append("vault decided-unbuilt must have empty served_by")
        print("  ok vault is decided-unbuilt, not live, not not-a-seam")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("VAULT CPCP FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("vault cpcp: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
