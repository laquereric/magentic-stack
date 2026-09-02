#!/usr/bin/env python3
"""Fail if the dual-v1 HTTP status contract loses a gap-109 invariant.

Plan freeze, not the mapper. Checks:

- mapping table exists; 200 is only for domain_decision
- grounding is 200, not 422; 422 is a different class
- admission.failure_layer is owner (do not guess the boundary)
- owner is not a wire value
- 503 retry is not generic
- RpcController still status: :ok at four sites while implemented is false
- rollout is per-method, not a controller-wide flip

Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

CONTRACT = Path("tooling/cpcp/cpcp_http_status.json")
CONTROLLER = Path("gems/rails-cpcp/app/controllers/rails_cpcp/rpc_controller.rb")
PLAN = Path("docs/architecture/GAP109.md")
WIRE_LAYERS = ("domain", "http_auth", "http_request", "infrastructure")
STATUS_OK = re.compile(r"status:\s*:ok\b")
STATUS_ANY = re.compile(r"status:\s*:(\w+)")


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
    if contract.get("schema") != "cpcp-http-status/v0":
        errors.append("schema must be cpcp-http-status/v0")
    if contract.get("profile") != "dual-v1":
        errors.append("profile must be dual-v1")
    if contract.get("default_profile") != "legacy-all-200":
        errors.append("default_profile must be legacy-all-200")
    if contract.get("env") != "CPCP_HTTP_STATUS_PROFILE":
        errors.append("env must be CPCP_HTTP_STATUS_PROFILE")
    if contract.get("implemented") is not False:
        errors.append("implemented must be false (this freeze does not flip the controller)")
    else:
        print("  ok profile dual-v1, default legacy-all-200, not implemented")

    examined += 1
    rollout = contract.get("rollout") or ""
    if "controller-wide" in rollout and "not" not in rollout:
        errors.append("rollout must forbid a controller-wide flip")
    if "per-method" not in rollout:
        errors.append("rollout must be per-method opt-in")
    else:
        print("  ok rollout is per-method, not controller-wide")

    examined += 1
    if contract.get("never_raise") is not True:
        errors.append("never_raise must be true")
    vault = contract.get("vault") or {}
    if "not copy" not in (vault.get("role") or "") and "not copy-verbatim" not in (vault.get("role") or ""):
        errors.append("vault must be a compatibility baseline, not copy-verbatim")
    else:
        print("  ok never-raise; vault is baseline not copy")

    env_spec = contract.get("envelope") or {}
    examined += 1
    enum = list(env_spec.get("failure_layer_enum") or [])
    if enum != list(WIRE_LAYERS):
        errors.append("failure_layer_enum must be %s, got %s" % (list(WIRE_LAYERS), enum))
    sentinel = env_spec.get("failure_layer_owner_sentinel") or ""
    if "never a wire value" not in sentinel:
        errors.append("owner sentinel must say owner is never a wire value")
    else:
        print("  ok failure_layer wire enum; owner is not on the wire")

    overlap = contract.get("grounding_vs_422") or {}
    examined += 1
    if overlap.get("decision") != "grounding is 200; 422 is a different event":
        errors.append("grounding_vs_422.decision must pick 200 for grounding")
    else:
        print("  ok grounding vs 422 is resolved: grounding is 200")

    classes = list(contract.get("classes") or [])
    examined += 1
    if not classes:
        errors.append("no classes in the mapping table")
    by_id = {}
    for row in classes:
        cid = row.get("id")
        if not cid:
            errors.append("a class has no id")
            continue
        if cid in by_id:
            errors.append("duplicate class id %s" % cid)
        by_id[cid] = row
        status = row.get("http_status")
        if not isinstance(status, int):
            errors.append("class %s missing integer http_status" % cid)
            continue
        kind = row.get("outcome_kind")
        if status == 200 and kind != "domain_decision":
            errors.append("class %s maps to 200 but outcome_kind is %s (200 is domain_decision only)" % (cid, kind))
        if kind == "domain_decision" and status != 200:
            errors.append("class %s is domain_decision but http_status is %s" % (cid, status))
        layer = row.get("failure_layer")
        if row.get("owner_call") is True:
            if layer != "owner":
                errors.append("owner-call class %s must have failure_layer owner, got %s" % (cid, layer))
        elif layer not in WIRE_LAYERS:
            errors.append("class %s failure_layer %s is not in the wire enum" % (cid, layer))
        if layer == "owner" and row.get("owner_call") is not True:
            errors.append("class %s uses owner without owner_call: true" % cid)
        retryable = row.get("retryable")
        status_i = status
        if status_i == 503 and retryable is True:
            errors.append("class %s is 503 with retryable true (503 is not a general retry signal)" % cid)
        if row.get("retry_after") is True:
            errors.append("class %s retry_after true; only only_known_window_and_safe_replay or false" % cid)

    grounding = by_id.get("grounding") or {}
    examined += 1
    if grounding.get("http_status") != 200:
        errors.append("grounding must be HTTP 200, got %s" % grounding.get("http_status"))
    if grounding.get("failure_layer") != "domain":
        errors.append("grounding failure_layer must be domain")
    if grounding.get("reason") != "grounding_refused":
        errors.append("grounding reason must be grounding_refused")
    req_doc = by_id.get("shacl_request_document") or {}
    if req_doc.get("http_status") != 422:
        errors.append("shacl_request_document must be HTTP 422")
    if req_doc.get("id") == "grounding" or grounding.get("http_status") == 422:
        errors.append("grounding and 422 collapsed into one event")
    if req_doc.get("live_producer") is not False:
        errors.append("shacl_request_document must record no live producer")
    else:
        print("  ok grounding 200 / request-document 422 are distinct")

    admission = by_id.get("admission") or {}
    examined += 1
    if admission.get("failure_layer") != "owner":
        errors.append("admission failure_layer must be owner (do not decide the boundary)")
    if admission.get("owner_call") is not True:
        errors.append("admission must be marked owner_call")
    if admission.get("http_status") != 200:
        errors.append("admission stays 200 as a completed method result; layer is the owner call")
    else:
        print("  ok admission layer is owner; status 200")

    parse = by_id.get("parse") or {}
    examined += 1
    if parse.get("http_status") != 400:
        errors.append("parse must be HTTP 400")
    retry = contract.get("retry") or {}
    if "not a general retry" not in (retry.get("rule") or ""):
        errors.append("retry.rule must say 503 is not a general retry signal")
    else:
        print("  ok parse 400; 503 is not a general retry")

    examined += 1
    ctrl_path = root / CONTROLLER
    if not ctrl_path.is_file():
        errors.append("missing %s" % CONTROLLER.as_posix())
        src = ""
    else:
        src = ctrl_path.read_text(encoding="utf-8", errors="replace")
        print("  ok %s" % CONTROLLER.as_posix())
    # Do not strip '#' -- "#{app_name}" on the cid render is interpolation, not a comment.
    ok_renders = len(STATUS_OK.findall(src))
    any_status = len(STATUS_ANY.findall(src))
    if ok_renders != 4:
        errors.append("RpcController must have 4 status: :ok renders while unimplemented, got %d" % ok_renders)
    if any_status != 4:
        errors.append("RpcController has a non-:ok status render (implementation leaked into the freeze)")
    if "dual-v1" in src or "HttpStatus" in src:
        errors.append("RpcController mentions dual-v1 / HttpStatus; mapper must not land in the freeze")
    if ok_renders == 4 and any_status == 4:
        print("  ok RpcController still all-200 at four sites")

    examined += 1
    callers = contract.get("callers") or {}
    ruby = list(callers.get("ruby_survive") or [])
    py = list(callers.get("python_break") or [])
    if len(ruby) != 3:
        errors.append("ruby_survive must list the three Net::HTTP callers, got %s" % ruby)
    if len(py) != 2:
        errors.append("python_break must list the two urlopen callers, got %s" % py)
    missing_callers = [rel for rel in ruby + py + list(callers.get("python_tests_break") or [])
                       if not (root / rel).is_file()]
    for rel in missing_callers:
        errors.append("caller path missing: %s" % rel)
    if len(ruby) == 3 and len(py) == 2 and not missing_callers:
        print("  ok caller inventory (3 ruby survive, 2 python break)")

    examined += 1
    plan_path = root / PLAN
    plan = plan_path.read_text(encoding="utf-8", errors="replace") if plan_path.is_file() else ""
    if not plan:
        errors.append("missing %s" % PLAN.as_posix())
    else:
        print("  ok %s" % PLAN.as_posix())
    if "grounding is 200" not in plan and "Grounding is HTTP 200" not in plan:
        errors.append("GAP109.md must say grounding is 200")
    if "failure_layer" not in plan:
        errors.append("GAP109.md must design failure_layer")
    if "owner" not in plan.lower():
        errors.append("GAP109.md must leave the admission layer as an owner call")
    if "Did not flip" not in plan and "Did not change RpcController" not in plan:
        errors.append("GAP109.md must record that RpcController was not flipped")

    ok_pop, _ = emit_population(examined, skipped=0)
    if not ok_pop:
        return 1
    if errors:
        print("CPCP HTTP STATUS FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("cpcp http status: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
